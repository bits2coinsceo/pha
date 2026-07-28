import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:logging_on_oslog/logging_on_oslog.dart';

/// Typed log categories for Console.app / Xcode filtering.
///
/// Each value becomes the `logging` logger name and the os_log **category**.
/// Subsystem is the iOS/macOS bundle id (via `logging_on_oslog`).
///
/// Filter in Console.app: subsystem = `com.pha.phaFlutter`, category = e.g. `auth`.
enum LogCategory {
  core('core'),
  bootstrap('bootstrap'),
  network('network'),
  api('api'),
  auth('auth'),
  ui('ui'),
  dashboard('dashboard'),
  db('db'),
  sync('sync'),
  reminders('reminders'),
  notifications('notifications'),
  health('health'),
  healthIndex('health_index');

  const LogCategory(this.id);

  /// Stable id used as Logger name / os_log category.
  final String id;
}

/// Advanced app logger: console + Apple `os_log`, category filters, release-safe.
///
/// ```dart
/// void main() {
///   AppLogger.init();
///   // Optional: only network + auth in console
///   // AppLogger.setEnabledCategories({LogCategory.network, LogCategory.auth});
///   runApp(const MyApp());
/// }
///
/// AppLogger.i('Signed in', category: LogCategory.auth);
/// AppLogger.e('Request failed', error: e, stackTrace: st, category: LogCategory.network);
/// ```
final class AppLogger {
  AppLogger._();

  static const bool _forceDebug = bool.fromEnvironment(
    'PHA_LOG_DEBUG',
    defaultValue: false,
  );

  static bool _initialized = false;
  static StreamSubscription<LogRecord>? _consoleSub;
  static StreamSubscription<LogRecord>? _osLogSub;

  /// `null` = all categories. Non-null = only these categories emit.
  static Set<LogCategory>? _enabledCategories;

  /// Categories explicitly silenced (wins over [_enabledCategories]).
  static final Set<LogCategory> _mutedCategories = {};

  static bool get debugLogsEnabled => !kReleaseMode || _forceDebug;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Call once before [runApp].
  ///
  /// - Debug / profile: verbose (`Level.FINE`+)
  /// - Release: `Level.WARNING`+ (override with `--dart-define=PHA_LOG_DEBUG=true`)
  static void init({
    Level? level,
    bool enableOsLog = true,
    bool enableConsole = true,
    Set<LogCategory>? enabledCategories,
  }) {
    if (_initialized) return;
    _initialized = true;

    hierarchicalLoggingEnabled = true;
    _enabledCategories = enabledCategories;

    final effective = level ??
        (debugLogsEnabled ? Level.FINE : Level.WARNING);
    Logger.root.level = effective;

    // Per-category child loggers inherit root level unless customized later.
    for (final cat in LogCategory.values) {
      Logger(cat.id).level = null; // inherit
    }

    if (enableConsole) {
      _consoleSub = Logger.root.onRecord.listen(_onConsole);
    }

    if (enableOsLog && _supportsOsLog) {
      try {
        _osLogSub = Logger.root.activateOsLog();
      } catch (e, st) {
        debugPrint('AppLogger: os_log failed: $e\n$st');
      }
    }

    i(
      'ready level=${effective.name} debug=$debugLogsEnabled '
      'osLog=${enableOsLog && _supportsOsLog} '
      'filter=${_enabledCategories?.map((c) => c.id).join(",") ?? "all"}',
      category: LogCategory.core,
    );
  }

  static Future<void> dispose() async {
    await _consoleSub?.cancel();
    await _osLogSub?.cancel();
    _consoleSub = null;
    _osLogSub = null;
    _initialized = false;
    _enabledCategories = null;
    _mutedCategories.clear();
  }

  // ── Category filters ─────────────────────────────────────────────────────

  /// Restrict output to these categories (`null` = allow all).
  static void setEnabledCategories(Set<LogCategory>? categories) {
    _enabledCategories = categories;
  }

  /// Mute a category (e.g. noisy `network` during UI work).
  static void mute(LogCategory category) => _mutedCategories.add(category);

  /// Unmute a previously muted category.
  static void unmute(LogCategory category) => _mutedCategories.remove(category);

  /// Raise/lower level for one category (hierarchical logging).
  static void setCategoryLevel(LogCategory category, Level? level) {
    Logger(category.id).level = level;
  }

  static bool _isAllowed(LogCategory category) {
    if (_mutedCategories.contains(category)) return false;
    final enabled = _enabledCategories;
    if (enabled == null) return true;
    return enabled.contains(category);
  }

  // ── Log API ──────────────────────────────────────────────────────────────

  static void d(
    String message, {
    LogCategory category = LogCategory.core,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!debugLogsEnabled) return;
    _emit(Level.FINE, message, category, error, stackTrace);
  }

  static void i(
    String message, {
    LogCategory category = LogCategory.core,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(Level.INFO, message, category, error, stackTrace);
  }

  static void w(
    String message, {
    LogCategory category = LogCategory.core,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(Level.WARNING, message, category, error, stackTrace);
  }

  static void e(
    String message, {
    LogCategory category = LogCategory.core,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _emit(Level.SEVERE, message, category, error, stackTrace);
  }

  /// Direct access to the underlying [Logger] for a category.
  static Logger of(LogCategory category) => Logger(category.id);

  // ── Internals ────────────────────────────────────────────────────────────

  static bool get _supportsOsLog => Platform.isIOS || Platform.isMacOS;

  static void _emit(
    Level level,
    String message,
    LogCategory category,
    Object? error,
    StackTrace? stackTrace,
  ) {
    if (!_isAllowed(category)) return;

    if (!_initialized) {
      debugPrint('[${level.name}][${category.id}] $message');
      if (error != null) debugPrint('  error: $error');
      if (stackTrace != null) debugPrint('$stackTrace');
      return;
    }

    Logger(category.id).log(level, message, error, stackTrace);
  }

  static void _onConsole(LogRecord record) {
    final time = record.time.toIso8601String().substring(11, 23);
    final level = record.level.name.padRight(7);
    final cat = record.loggerName;
    final mark = switch (record.level) {
      >= Level.SEVERE => 'E',
      >= Level.WARNING => 'W',
      >= Level.INFO => 'I',
      _ => 'D',
    };

    final out = StringBuffer('[$mark] $time [$level][$cat] ${record.message}');
    if (record.error != null) out.write('\n  ↳ ${record.error}');
    if (record.stackTrace != null) out.write('\n${record.stackTrace}');
    // ignore: avoid_print
    print(out);
  }
}
