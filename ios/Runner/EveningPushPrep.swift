import BackgroundTasks
import Flutter
import Foundation
import HealthKit
import UserNotifications

/// Refreshes the 20:00 evening local notification from HealthKit.
///
/// The banner must not stay frozen at the step count from the last time PHA
/// was opened. HealthKit wakes the app when new steps are saved
/// (`enableBackgroundDelivery` + `HKObserverQuery`) and the pending
/// notification is rewritten with today's cumulative total. A background
/// refresh a few minutes before 20:00 is a second chance if iOS runs it.
///
/// Template placeholders: `__TODAY__`, `__YESTERDAY__`.
enum EveningPushPrep {
  static let preEveningTaskId = "com.pha.phaFlutter.eveningPrep.prePush"
  static let methodChannelName = "pha.evening_push_prep/methods"
  static let notificationId = "1002"

  private static let defaults = UserDefaults.standard
  private static let healthStore = HKHealthStore()
  private static let titleKey = "pha_evening_os_title"
  private static let templateKey = "pha_evening_os_body_template"
  private static let fallbackKey = "pha_evening_os_body_fallback"
  private static let fireAtKey = "pha_evening_os_fire_at_ms"
  private static let prePushKey = "pha_evening_os_prepush_ms"
  private static let lastTodayKey = "pha_evening_os_last_today"
  private static let lastTodayDayKey = "pha_evening_os_last_today_day"
  private static let lastYesterdayKey = "pha_evening_os_last_yesterday"
  private static let lastYesterdayDayKey = "pha_evening_os_last_yesterday_day"

  private static var observerQuery: HKObserverQuery?
  private static var lastRefreshAt = Date.distantPast
  private static let refreshLock = NSLock()

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
          ?? (fireAtMs.doubleValue - 5 * 60_000)

        defaults.set(title, forKey: titleKey)
        defaults.set(template, forKey: templateKey)
        defaults.set(fallback, forKey: fallbackKey)
        defaults.set(fireAtMs.doubleValue, forKey: fireAtKey)
        defaults.set(prePushMs, forKey: prePushKey)

        startHealthKitDelivery()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: preEveningTaskId)
        refreshPendingNotification(fireAtMs: fireAtMs.doubleValue, force: true) { _ in
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

  /// Call from `didFinishLaunching` so a HealthKit background wake can update
  /// the 20:00 banner before Flutter starts.
  static func startHealthKitDelivery() {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else { return }

    healthStore.enableBackgroundDelivery(for: stepsType, frequency: .immediate) { success, error in
      if let error {
        NSLog("EveningPushPrep: background delivery failed \(error.localizedDescription)")
      } else {
        NSLog("EveningPushPrep: background delivery enabled=\(success)")
      }
    }

    guard observerQuery == nil else { return }
    let query = HKObserverQuery(sampleType: stepsType, predicate: nil) { _, completionHandler, error in
      if let error {
        NSLog("EveningPushPrep: observer error \(error.localizedDescription)")
        completionHandler()
        return
      }
      let fireAtMs = defaults.double(forKey: fireAtKey)
      guard defaults.string(forKey: templateKey) != nil, fireAtMs > 0 else {
        completionHandler()
        return
      }
      let fireAt = upcomingFireDate(storedFireAtMs: fireAtMs) ?? Date()
      let nearFire = fireAt.timeIntervalSinceNow > 0 && fireAt.timeIntervalSinceNow < 20 * 60
      if !nearFire && Date().timeIntervalSince(lastRefreshAt) < 30 {
        completionHandler()
        return
      }
      refreshPendingNotification(fireAtMs: fireAtMs, force: nearFire) { _ in
        completionHandler()
      }
    }
    observerQuery = query
    healthStore.execute(query)
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
    refreshPendingNotification(fireAtMs: fireAtMs, force: true) { _ in
      let fireAt = upcomingFireDate(storedFireAtMs: fireAtMs)
        ?? Date(timeIntervalSince1970: fireAtMs / 1000.0)
      // If iOS woke us early, ask for one more pass about a minute before 20:00.
      if fireAt.timeIntervalSinceNow > 3 * 60 {
        let retryMs = fireAt.addingTimeInterval(-60).timeIntervalSince1970 * 1000
        scheduleBackgroundRefresh(earliestMs: retryMs, label: "preEvening-retry")
      }
      task.setTaskCompleted(success: true)
    }
  }

  /// Next 20:00 the pending banner is for. A repeating trigger stays after
  /// today's fire time, so a stored timestamp in the past means "tomorrow".
  private static func upcomingFireDate(storedFireAtMs: Double) -> Date? {
    guard storedFireAtMs > 0 else { return nil }
    let stored = Date(timeIntervalSince1970: storedFireAtMs / 1000.0)
    if stored.timeIntervalSinceNow > 15 { return stored }
    let cal = Calendar.current
    let comps = cal.dateComponents([.hour, .minute], from: stored)
    return cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
  }

  /// Today = calendar day of the upcoming evening fire; yesterday = day before.
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

  /// `nil` means the query failed — caller must not replace a real count with 0.
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
        completion(nil)
        return
      }
      let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
      completion(Int(value.rounded()))
    }
    healthStore.execute(query)
  }

  /// Step totals only grow during a calendar day. A later HealthKit read that
  /// is lower (or a failed read) must not wipe a higher total already seen.
  private static func resolvedCount(
    fresh: Int?,
    day: Date,
    countKey: String,
    dayKey: String
  ) -> Int? {
    let token = dayToken(day)
    let stored = defaults.string(forKey: dayKey) == token
      ? defaults.integer(forKey: countKey)
      : 0
    if fresh == nil && stored == 0 { return nil }
    let value = max(fresh ?? 0, stored)
    if value > 0 {
      defaults.set(value, forKey: countKey)
      defaults.set(token, forKey: dayKey)
    }
    return value
  }

  private static func dayToken(_ date: Date) -> String {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
  }

  private static func refreshPendingNotification(
    fireAtMs: Double,
    force: Bool,
    completion: @escaping (Bool) -> Void
  ) {
    guard fireAtMs > 0 else {
      completion(false)
      return
    }
    guard let fireAt = upcomingFireDate(storedFireAtMs: fireAtMs),
          let bounds = dayBounds(forFireAt: fireAt)
    else {
      completion(false)
      return
    }

    refreshLock.lock()
    let tooSoon = !force && Date().timeIntervalSince(lastRefreshAt) < 30
    if !tooSoon {
      lastRefreshAt = Date()
    }
    refreshLock.unlock()
    if tooSoon {
      completion(true)
      return
    }

    fetchSteps(from: bounds.todayStart, to: bounds.todayEnd) { todayFresh in
      fetchSteps(from: bounds.yesterdayStart, to: bounds.todayStart) { yesterdayFresh in
        let today = resolvedCount(
          fresh: todayFresh,
          day: bounds.todayStart,
          countKey: lastTodayKey,
          dayKey: lastTodayDayKey
        )
        let yesterday = resolvedCount(
          fresh: yesterdayFresh,
          day: bounds.yesterdayStart,
          countKey: lastYesterdayKey,
          dayKey: lastYesterdayDayKey
        ) ?? 0
        // A zero/failed read must not replace the scheduled banner.
        guard let today, today > 0 else {
          NSLog("EveningPushPrep: skip body update — HealthKit today=\(String(describing: todayFresh))")
          completion(false)
          return
        }
        applyBody(today: today, yesterday: yesterday, completion: completion)
      }
    }
  }

  private static func applyBody(
    today: Int,
    yesterday: Int,
    completion: @escaping (Bool) -> Void
  ) {
    guard let title = defaults.string(forKey: titleKey) else {
      completion(false)
      return
    }
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
        completion(false)
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
          completion(false)
        } else {
          NSLog("EveningPushPrep: updated evening body from HealthKit (today=\(today) yesterday=\(yesterday))")
          completion(true)
        }
      }
    }
  }
}
