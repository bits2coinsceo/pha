import Flutter
import Foundation
import HealthKit

/// Streams heart-rate samples from HealthKit as soon as they arrive.
///
/// Apple Watch live optical HR is only written to HealthKit when the Watch
/// saves samples (often every few minutes unless a workout / Heart Rate app
/// session is active). This plugin cannot invent 1 Hz Watch BPM without a
/// watchOS companion — it only pushes the newest HealthKit sample immediately.
final class LiveHeartRatePlugin: NSObject, FlutterStreamHandler {
  static let methodChannelName = "pha.live_heart_rate/methods"
  static let eventChannelName = "pha.live_heart_rate/events"

  private let store = HKHealthStore()
  private var query: HKAnchoredObjectQuery?
  private var anchor: HKQueryAnchor?
  private var eventSink: FlutterEventSink?
  private var running = false

  static func register(with messenger: FlutterBinaryMessenger) {
    let plugin = LiveHeartRatePlugin()
    let methods = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    methods.setMethodCallHandler { call, result in
      switch call.method {
      case "start":
        plugin.startObserving()
        result(nil)
      case "stop":
        plugin.stopObserving()
        result(nil)
      case "latest":
        plugin.fetchLatest { payload in
          result(payload)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let events = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: messenger
    )
    events.setStreamHandler(plugin)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    startObserving()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopObserving()
    return nil
  }

  private func startObserving() {
    guard HKHealthStore.isHealthDataAvailable() else { return }
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else { return }
    if running { return }
    running = true

    store.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in
      // Best-effort; foreground updateHandler still works without this.
    }

    let start = Date().addingTimeInterval(-2 * 60 * 60)
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: nil,
      options: .strictStartDate
    )

    let q = HKAnchoredObjectQuery(
      type: hrType,
      predicate: predicate,
      anchor: anchor,
      limit: HKObjectQueryNoLimit
    ) { [weak self] _, samples, _, newAnchor, _ in
      guard let self else { return }
      if let newAnchor { self.anchor = newAnchor }
      self.emitNewest(from: samples)
    }
    q.updateHandler = { [weak self] _, samples, _, newAnchor, _ in
      guard let self else { return }
      if let newAnchor { self.anchor = newAnchor }
      self.emitNewest(from: samples)
    }
    query = q
    store.execute(q)

    // Immediate one-shot so the UI has a value without waiting for an update.
    fetchLatest { [weak self] payload in
      guard let self, let payload else { return }
      self.emit(payload)
    }
  }

  private func stopObserving() {
    running = false
    if let query {
      store.stop(query)
    }
    query = nil
  }

  private func fetchLatest(completion: @escaping ([String: Any]?) -> Void) {
    guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    else {
      completion(nil)
      return
    }
    let start = Date().addingTimeInterval(-6 * 60 * 60)
    let predicate = HKQuery.predicateForSamples(
      withStart: start,
      end: Date(),
      options: .strictStartDate
    )
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
    let q = HKSampleQuery(
      sampleType: hrType,
      predicate: predicate,
      limit: 1,
      sortDescriptors: [sort]
    ) { _, samples, _ in
      let payload = Self.payload(from: samples?.first as? HKQuantitySample)
      DispatchQueue.main.async { completion(payload) }
    }
    store.execute(q)
  }

  private func emitNewest(from samples: [HKSample]?) {
    guard let samples, !samples.isEmpty else { return }
    let newest = samples
      .compactMap { $0 as? HKQuantitySample }
      .max(by: { $0.endDate < $1.endDate })
    guard let payload = Self.payload(from: newest) else { return }
    emit(payload)
  }

  private func emit(_ payload: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }

  private static func payload(from sample: HKQuantitySample?) -> [String: Any]? {
    guard let sample else { return nil }
    let unit = HKUnit.count().unitDivided(by: .minute())
    let bpm = sample.quantity.doubleValue(for: unit)
    guard bpm > 0, bpm <= 250 else { return nil }
    return [
      "bpm": bpm,
      "atMs": Int((sample.endDate.timeIntervalSince1970 * 1000.0).rounded()),
    ]
  }
}
