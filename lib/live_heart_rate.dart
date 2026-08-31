import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'heart_rate_service.dart';

/// Native HealthKit push stream for the newest heart-rate sample.
///
/// On iOS this uses an anchored HealthKit query. It cannot invent live Watch
/// optical BPM that has not been written to Apple Health yet.
class LiveHeartRate {
  LiveHeartRate._();

  static const _methods = MethodChannel('pha.live_heart_rate/methods');
  static const _events = EventChannel('pha.live_heart_rate/events');

  static StreamSubscription? _sub;
  static final _controller = StreamController<HeartSample>.broadcast();
  static bool _started = false;

  static Stream<HeartSample> get samples => _controller.stream;

  static bool get isSupported => !kIsWeb && Platform.isIOS;

  static Future<void> start() async {
    if (!isSupported) return;
    if (_started) return;
    _started = true;
    try {
      await _methods.invokeMethod<void>('start');
    } catch (e) {
      debugPrint('LiveHeartRate.start failed: $e');
    }
    _sub ??= _events.receiveBroadcastStream().listen(
      (event) {
        final sample = _parse(event);
        if (sample != null) _controller.add(sample);
      },
      onError: (Object e) => debugPrint('LiveHeartRate stream error: $e'),
    );
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    _started = false;
    await _sub?.cancel();
    _sub = null;
    try {
      await _methods.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('LiveHeartRate.stop failed: $e');
    }
  }

  /// One-shot latest sample from native HealthKit (bypasses Flutter health plugin).
  static Future<HeartSample?> latest() async {
    if (!isSupported) {
      return HeartRateService.fetchLatestSample(
        lookback: const Duration(hours: 2),
        timeout: const Duration(seconds: 3),
      );
    }
    try {
      final raw = await _methods.invokeMethod<dynamic>('latest');
      return _parse(raw) ??
          await HeartRateService.fetchLatestSample(
            lookback: const Duration(hours: 2),
            timeout: const Duration(seconds: 3),
          );
    } catch (e) {
      debugPrint('LiveHeartRate.latest failed: $e');
      return HeartRateService.fetchLatestSample(
        lookback: const Duration(hours: 2),
        timeout: const Duration(seconds: 3),
      );
    }
  }

  static HeartSample? _parse(dynamic event) {
    if (event is! Map) return null;
    final bpm = (event['bpm'] as num?)?.toDouble();
    final atMs = (event['atMs'] as num?)?.toInt();
    if (bpm == null || atMs == null || bpm <= 0) return null;
    return HeartSample(
      DateTime.fromMillisecondsSinceEpoch(atMs),
      bpm,
    );
  }
}
