import BackgroundTasks
import Flutter
import Foundation
import HealthKit
import UserNotifications

/// Refreshes the pending 10:30 morning local notification with finalized
/// yesterday step counts from HealthKit shortly before it fires.
///
/// Flutter writes a body template (`__STEPS__` placeholder) into UserDefaults;
/// this task replaces the placeholder and re-queues notification id 1001.
enum MorningPushPrep {
  static let taskId = "com.pha.phaFlutter.morningPrep"
  static let methodChannelName = "pha.morning_push_prep/methods"
  static let notificationId = "1001"

  private static let defaults = UserDefaults.standard
  private static let titleKey = "pha_morning_os_title"
  private static let templateKey = "pha_morning_os_body_template"
  private static let fireAtKey = "pha_morning_os_fire_at_ms"

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
        defaults.set(title, forKey: titleKey)
        defaults.set(template, forKey: templateKey)
        defaults.set(fireAtMs.doubleValue, forKey: fireAtKey)
        scheduleBackgroundRefresh(fireAtMs: fireAtMs.doubleValue)
        result(nil)
      case "cancel":
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func registerBackgroundTask() {
    BGTaskScheduler.shared.register(
      forTaskWithIdentifier: taskId,
      using: nil
    ) { task in
      guard let refresh = task as? BGAppRefreshTask else {
        task.setTaskCompleted(success: false)
        return
      }
      handle(refresh)
    }
  }

  private static func scheduleBackgroundRefresh(fireAtMs: Double) {
    let fireAt = Date(timeIntervalSince1970: fireAtMs / 1000.0)
    // Wake ~20 minutes before the banner so HealthKit totals for yesterday
    // are finalized and the pending notification body can be rewritten.
    let earliest = fireAt.addingTimeInterval(-20 * 60)
    let request = BGAppRefreshTaskRequest(identifier: taskId)
    request.earliestBeginDate = max(earliest, Date().addingTimeInterval(60))
    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      NSLog("MorningPushPrep: failed to submit BG task: \(error)")
    }
  }

  private static func handle(_ task: BGAppRefreshTask) {
    // Chain the next attempt in case iOS deferred this run.
    let fireAtMs = defaults.double(forKey: fireAtKey)
    if fireAtMs > 0 {
      scheduleBackgroundRefresh(fireAtMs: fireAtMs)
    }

    let queue = DispatchQueue.global(qos: .userInitiated)
    task.expirationHandler = {
      queue.async { /* cancelled by system */ }
    }

    queue.async {
      fetchYesterdaySteps { steps in
        defer { task.setTaskCompleted(success: true) }
        guard let steps else { return }
        updatePendingMorningNotification(steps: steps)
      }
    }
  }

  private static func fetchYesterdaySteps(completion: @escaping (Int?) -> Void) {
    guard HKHealthStore.isHealthDataAvailable(),
          let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount)
    else {
      completion(nil)
      return
    }

    let store = HKHealthStore()
    let cal = Calendar.current
    let todayStart = cal.startOfDay(for: Date())
    guard let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)
    else {
      completion(nil)
      return
    }

    let predicate = HKQuery.predicateForSamples(
      withStart: yesterdayStart,
      end: todayStart,
      options: .strictStartDate
    )
    let query = HKStatisticsQuery(
      quantityType: stepsType,
      quantitySamplePredicate: predicate,
      options: .cumulativeSum
    ) { _, stats, _ in
      let value = stats?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
      completion(Int(value.rounded()))
    }
    store.execute(query)
  }

  private static func updatePendingMorningNotification(steps: Int) {
    guard let template = defaults.string(forKey: templateKey),
          let title = defaults.string(forKey: titleKey),
          !template.isEmpty
    else { return }

    let body = template.replacingOccurrences(of: "__STEPS__", with: "\(steps)")
    let center = UNUserNotificationCenter.current()
    center.getPendingNotificationRequests { requests in
      guard let existing = requests.first(where: { $0.identifier == notificationId }),
            let trigger = existing.trigger
      else { return }

      let content = UNMutableNotificationContent()
      content.title = title
      content.body = body
      content.sound = existing.content.sound
      content.userInfo = existing.content.userInfo
      content.categoryIdentifier = existing.content.categoryIdentifier
      content.threadIdentifier = existing.content.threadIdentifier

      let updated = UNNotificationRequest(
        identifier: notificationId,
        content: content,
        trigger: trigger
      )
      center.add(updated, withCompletionHandler: nil)
    }
  }
}
