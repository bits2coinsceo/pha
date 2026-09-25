import BackgroundTasks
import Flutter
import Foundation
import HealthKit
import UserNotifications

/// Refreshes the 20:00 evening local notification with today's step count.
///
/// Cadence:
/// 1. Immediately when Flutter schedules the push
/// 2. 30 minutes before 20:00 (HealthKit late sync / Watch)
///
/// Template placeholders: `__TODAY__`, `__YESTERDAY__`.
enum EveningPushPrep {
  static let preEveningTaskId = "com.pha.phaFlutter.eveningPrep.prePush"
  static let methodChannelName = "pha.evening_push_prep/methods"
  static let notificationId = "1002"

  private static let defaults = UserDefaults.standard
  private static let titleKey = "pha_evening_os_title"
  private static let templateKey = "pha_evening_os_body_template"
  private static let fallbackKey = "pha_evening_os_body_fallback"
  private static let fireAtKey = "pha_evening_os_fire_at_ms"
  private static let prePushKey = "pha_evening_os_prepush_ms"

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
        let prePushMs = (args["prePushMs"] as? NSNumber)?.doubleValue
          ?? (fireAtMs.doubleValue - 30 * 60_000)

        defaults.set(title, forKey: titleKey)
        defaults.set(template, forKey: templateKey)
        defaults.set(fallback, forKey: fallbackKey)
        defaults.set(fireAtMs.doubleValue, forKey: fireAtKey)
        defaults.set(prePushMs, forKey: prePushKey)

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: preEveningTaskId)
        refreshPendingNotification(fireAtMs: fireAtMs.doubleValue) { _ in
          scheduleBackgroundRefresh(earliestMs: prePushMs, label: "preEvening")
          result(nil)
        }
      case "cancel":
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: preEveningTaskId)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: preEveningTaskId,
      using: nil
    ) { task in
      guard let refresh = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refresh)
    }
  }

  private static func scheduleBackgroundRefresh(earliestMs: Double, label: String) {
    let earliest = Date(timeIntervalSince1970: earliestMs / 1000.0)
    guard earliest.timeIntervalSinceNow > 15 else {
      NSLog("EveningPushPrep: skip \(label) — already past")
      return
    }
    let request = BGAppRefreshTaskRequest(identifier: preEveningTaskId)
    request.earliestBeginDate = earliest
    do {
      try BGTaskScheduler.shared.submit(request)
      NSLog("EveningPushPrep: scheduled \(label) BG for \(earliest)")
    } catch {
      NSLog("EveningPushPrep: failed to submit \(label) BG: \(error)")
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    let fireAtMs = defaults.double(forKey: fireAtKey)
    task.expirationHandler = {
      NSLog("EveningPushPrep: BG expired")
    }
    refreshPendingNotification(fireAtMs: fireAtMs) { _ in
      let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
      // Re-arm once if we woke early.
      if fireAt.timeIntervalSinceNow > 90 {
        let retryMs = (fireAt.addingTimeInterval(-30 * 60)).timeIntervalSince1970 * 1000
        scheduleBackgroundRefresh(earliestMs: retryMs, label: "preEvening-retry")
      }
      task.setTaskCompleted(success: true)
    }
  }

  /// Today = calendar day of [fireAt]; yesterday = day before.
  private static func dayBounds(forFireAt fireAt: Date) -> (
    todayStart: Date,
    todayEnd: Date,
    yesterdayStart: Date
  )? {
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: fireAt)
    guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart),
          let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)
    else { return nil }
    return (todayStart, todayEnd, yesterdayStart)
  }

  private static func fetchSteps(
    from start: Date,
    to end: Date,
    completion: @escaping (Int) -> Void
  ) {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else {
      completion(0)
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
        NSLog("EveningPushPrep: HealthKit error \(error.localizedDescription)")
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
    guard let bounds = dayBounds(forFireAt: fireAt) else {
      completion(false)
      return
    }

    fetchSteps(from: bounds.todayStart, to: bounds.todayEnd) { today in
      fetchSteps(from: bounds.yesterdayStart, to: bounds.todayStart) { yesterday in
        applyBody(today: today, yesterday: yesterday)
        completion(true)
      }
    }
  }

  private static func applyBody(today: Int, yesterday: Int) {
    guard let title = defaults.string(forKey: titleKey) else { return }
    let template = defaults.string(forKey: templateKey) ?? ""
    let fallback = defaults.string(forKey: fallbackKey) ?? template
    let fireAtMs = defaults.double(forKey: fireAtKey)

    let body: String
    if !template.isEmpty {
      body = template
        .replacingOccurrences(of: "__TODAY__", with: "\(today)")
        .replacingOccurrences(of: "__YESTERDAY__", with: "\(yesterday)")
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
        NSLog("EveningPushPrep: pending \(notificationId) missing — recreating")
        let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: fireAt)
        trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
      } else {
        NSLog("EveningPushPrep: pending notification \(notificationId) not found")
        return
      }

      let updated = UNNotificationRequest(
        identifier: notificationId,
        content: content,
        trigger: trigger
      )
      center.add(updated) { error in
        if let error {
          NSLog("EveningPushPrep: failed to update notification: \(error)")
        } else {
          NSLog("EveningPushPrep: updated evening body (today=\(today) yesterday=\(yesterday))")
        }
      }
    }
  }
}
