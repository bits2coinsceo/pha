import BackgroundTasks
import Flutter
import Foundation
import HealthKit
import UserNotifications

/// Keeps the pending 10:30 morning local notification body accurate.
///
/// Refresh cadence (requested; iOS may defer BGAppRefresh slightly):
/// 1. Immediately when Flutter schedules the push
/// 2. At 00:00 on the delivery calendar day (yesterday's steps are finalized)
/// 3. 1 minute before the push fires (late Watch / HealthKit sync)
///
/// Flutter stores a `__STEPS__` body template (+ fallback). Native fills steps
/// from HealthKit for the calendar day *before* [fireAt].
enum MorningPushPrep {
  static let midnightTaskId = "com.pha.phaFlutter.morningPrep.midnight"
  static let prePushTaskId = "com.pha.phaFlutter.morningPrep.prePush"
  /// Legacy id — still cancelled on schedule so old installs clean up.
  static let legacyTaskId = "com.pha.phaFlutter.morningPrep"
  static let methodChannelName = "pha.morning_push_prep/methods"
  static let notificationId = "1001"

  private static let defaults = UserDefaults.standard
  private static let titleKey = "pha_morning_os_title"
  private static let templateKey = "pha_morning_os_body_template"
  private static let fallbackKey = "pha_morning_os_body_fallback"
  private static let fireAtKey = "pha_morning_os_fire_at_ms"
  private static let midnightKey = "pha_morning_os_midnight_ms"
  private static let prePushKey = "pha_morning_os_prepush_ms"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "schedule":
        guard let args = call.arguments as? [String: Any],
              let fireAtMs = args["fireAtMs"] as? NSNumber,
              let title = args["title"] as? String,
              let template = args["bodyTemplate"] as? String
        else {
          result(
            FlutterError(
              code: "bad_args",
              message: "Expected fireAtMs, title, bodyTemplate",
              details: nil
            )
          )
          return
        }
        let fallback = (args["bodyFallback"] as? String) ?? template
        let midnightMs = (args["midnightMs"] as? NSNumber)?.doubleValue
          ?? Self.defaultMidnightMs(fireAtMs: fireAtMs.doubleValue)
        let prePushMs = (args["prePushMs"] as? NSNumber)?.doubleValue
          ?? (fireAtMs.doubleValue - 60_000)

        defaults.set(title, forKey: titleKey)
        defaults.set(template, forKey: templateKey)
        defaults.set(fallback, forKey: fallbackKey)
        defaults.set(fireAtMs.doubleValue, forKey: fireAtKey)
        defaults.set(midnightMs, forKey: midnightKey)
        defaults.set(prePushMs, forKey: prePushKey)

        cancelAllBackgroundTasks()
        // 1) Immediate HealthKit fill for the correct "yesterday".
        refreshPendingNotification(fireAtMs: fireAtMs.doubleValue) { _ in
          // 2) 00:00 on delivery day  3) 1 minute before push
          scheduleBackgroundRefresh(
            taskId: midnightTaskId,
            earliestMs: midnightMs,
            label: "midnight"
          )
          scheduleBackgroundRefresh(
            taskId: prePushTaskId,
            earliestMs: prePushMs,
            label: "prePush"
          )
          result(nil)
        }
      case "cancel":
        cancelAllBackgroundTasks()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func registerBackgroundTask() {
    let handler: (BGTask) -> Void = { task in
      guard let refresh = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refresh)
    }
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: midnightTaskId,
      using: nil,
      launchHandler: handler
    )
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: prePushTaskId,
      using: nil,
      launchHandler: handler
    )
    // Keep legacy registration so iOS never crashes on an old pending request.
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: legacyTaskId,
      using: nil,
      launchHandler: handler
    )
  }

  private static func cancelAllBackgroundTasks() {
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: midnightTaskId)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: prePushTaskId)
    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: legacyTaskId)
  }

  private static func defaultMidnightMs(fireAtMs: Double) -> Double {
    let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
    let deliveryStart = Calendar.current.startOfDay(for: fireAt)
    return deliveryStart.timeIntervalSince1970 * 1000.0
  }

  private static func scheduleBackgroundRefresh(
    taskId: String,
    earliestMs: Double,
    label: String
  ) {
    let earliest = Date(timeIntervalSince1970: earliestMs / 1000.0)
    // Skip checkpoints that are already in the past (or within 15s).
    guard earliest.timeIntervalSinceNow > 15 else {
      NSLog("MorningPushPrep: skip \(label) — already past")
      return
    }
    let request = BGAppRefreshTaskRequest(identifier: taskId)
    // iOS treats earliestBeginDate as a hint; still the best API for wake-ups.
    request.earliestBeginDate = earliest
    do {
      try BGTaskScheduler.shared.submit(request)
      NSLog(
        "MorningPushPrep: scheduled \(label) BG for \(earliest)"
      )
    } catch {
      NSLog("MorningPushPrep: failed to submit \(label) BG: \(error)")
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    let fireAtMs = defaults.double(forKey: fireAtKey)
    let taskId = task.identifier

    task.expirationHandler = {
      NSLog("MorningPushPrep: BG \(taskId) expired")
    }

    refreshPendingNotification(fireAtMs: fireAtMs) { _ in
      // After midnight run, ensure the pre-push wake is still queued.
      if taskId == midnightTaskId {
        let prePushMs = defaults.double(forKey: prePushKey)
        if prePushMs > 0 {
          scheduleBackgroundRefresh(
            taskId: prePushTaskId,
            earliestMs: prePushMs,
            label: "prePush-rearm"
          )
        }
      }
      // If pre-push ran early, re-arm once more closer to fire time.
      if taskId == prePushTaskId {
        let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
        let retryMs = (fireAt.addingTimeInterval(-60)).timeIntervalSince1970 * 1000
        if fireAt.timeIntervalSinceNow > 90 {
          scheduleBackgroundRefresh(
            taskId: prePushTaskId,
            earliestMs: retryMs,
            label: "prePush-retry"
          )
        }
      }
      task.setTaskCompleted(success: true)
    }
  }

  /// Steps for the local calendar day immediately before [fireAt].
  private static func yesterdayBounds(forFireAt fireAt: Date) -> (start: Date, end: Date)? {
    let cal = Calendar.current
    let deliveryStart = cal.startOfDay(for: fireAt)
    guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: deliveryStart)
    else { return nil }
    return (yesterdayStart, deliveryStart)
  }

  private static func fetchSteps(
    from start: Date,
    to end: Date,
    completion: @escaping (Int?) -> Void
  ) {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else {
      completion(nil)
      return
    }

    let store = HKHealthStore()
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: end,
      options: .strictStartDate
    )
    let query = HKStatisticsQuery(
      quantityType: stepsType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, stats, error in
      if let error {
        NSLog("MorningPushPrep: HealthKit error \(error.localizedDescription)")
      }
      let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
      completion(Int(value.rounded()))
    }
    store.execute(query)
  }

  private static func refreshPendingNotification(
    fireAtMs: Double,
    completion: @escaping (Bool) -> Void
  ) {
    guard fireAtMs > 0 else {
      completion(false)
      return
    }
    let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
    guard let bounds = yesterdayBounds(forFireAt: fireAt) else {
      completion(false)
      return
    }

    fetchSteps(from: bounds.start, to: bounds.end) { steps in
      applyBody(steps: steps)
      completion(steps != nil)
    }
  }

  private static func applyBody(steps: Int?) {
    guard let title = defaults.string(forKey: titleKey) else { return }
    let template = defaults.string(forKey: templateKey) ?? ""
    let fallback = defaults.string(forKey: fallbackKey) ?? template
    let fireAtMs = defaults.double(forKey: fireAtKey)

    let body: String
    if !template.isEmpty {
      // Always include a step count in the morning OS push (0 is valid).
      body = template.replacingOccurrences(
        of: "__STEPS__",
        with: "\(steps ?? 0)"
      )
    } else {
      body = fallback
    }

    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = .default
      content.interruptionLevel = .active

      let trigger: UNNotificationTrigger
      if let existing = requests.first(where: { $0.identifier == notificationId }),
         let existingTrigger = existing.trigger
      {
        content.userInfo = existing.content.userInfo
        content.categoryIdentifier = existing.content.categoryIdentifier
        content.threadIdentifier = existing.content.threadIdentifier
        if let sound = existing.content.sound {
          content.sound = sound
        }
        trigger = existingTrigger
      } else if fireAtMs > 0 {
        // Flutter schedule may have been cleared after kill — re-arm a daily
        // calendar trigger at the same local clock time as fireAt.
        NSLog("MorningPushPrep: pending \(notificationId) missing — recreating")
        let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
        let comps = Calendar.current.dateComponents(
          [.hour, .minute],
          from: fireAt
        )
        trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
      } else {
        NSLog("MorningPushPrep: pending notification \(notificationId) not found")
        return
      }

      let updated = UNNotificationRequest(
        identifier: notificationId,
        content: content,
        trigger: trigger
      )
      center.add(updated) { error in
        if let error {
          NSLog("MorningPushPrep: failed to update notification: \(error)")
        } else {
          NSLog("MorningPushPrep: updated morning body (steps=\(steps ?? -1))")
        }
      }
    }
  }
}
