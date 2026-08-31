import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'core/app_logger.dart';

/// Configuration for the PHA backend (FastAPI + Vertex AI Gemini).
///
/// Compile-time values come from `--dart-define-from-file=dart_define.json`.
/// If those are missing (e.g. hot restart without defines), [ensureLoaded]
/// falls back to the bundled `dart_define.json` asset when present.
class ApiConfig {
  static const _baseUrlEnv = String.fromEnvironment(
    'PHA_API_BASE',
    defaultValue: 'http://49.13.66.150:8080',
  );
  static const _apiKeyEnv = String.fromEnvironment('PHA_API_KEY', defaultValue: '');

  static String baseUrl = _baseUrlEnv;
  static String apiKey = _apiKeyEnv;

  static bool _loaded = false;

  /// Load API settings from the bundled dart_define.json when compile-time
  /// defines were not applied to the running isolate.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    if (apiKey.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString('dart_define.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final key = json['PHA_API_KEY'] as String?;
      final base = json['PHA_API_BASE'] as String?;
      if (key != null && key.isNotEmpty) apiKey = key;
      if (base != null && base.isNotEmpty) baseUrl = base;
    } catch (_) {
      // Asset absent or invalid — rely on compile-time defines only.
    }
  }
}

/// Error carrying the backend's HTTP status + `detail` message.
/// Status 402 means the user's credit budget is exhausted.
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  bool get isBudgetExhausted => status == 402;
  bool get isAuthError => status == 401 || status == 403;

  /// Vertex/Gemini quota or rate limit (HTTP 429, or 502 wrapping a 429).
  bool get isRateLimited {
    if (status == 429) return true;
    final m = message.toLowerCase();
    return m.contains('429') ||
        m.contains('resource has been exhausted') ||
        m.contains('resource_exhausted') ||
        m.contains('busy') ||
        m.contains('usage limit') ||
        m.contains('rate limit') ||
        (m.contains('quota') && m.contains('exhaust'));
  }

  /// Temporary backend/network failures worth retrying.
  bool get isTransient =>
      status == 408 || status == 502 || status == 503 || status == 504;

  /// Safe message for UI — never dumps raw Vertex URLs or stack traces.
  String get userFacingMessage {
    if (isBudgetExhausted) {
      return 'You have reached your AI usage limit. Upgrade to PHA Plus+ to continue.';
    }
    if (isRateLimited) {
      return 'The AI service is busy right now (usage limit). Please wait a minute and try again.';
    }
    if (isAuthError) {
      return 'Could not reach the AI service. Check your connection and try again.';
    }
    if (message.toLowerCase().startsWith('model error:')) {
      return 'Meal analysis is temporarily unavailable. Please try again in a moment.';
    }
    return message;
  }

  @override
  String toString() => message;
}

/// Retry Gemini/backend calls with exponential backoff (1s → 2s → 4s → 8s).
///
/// By default retries rate-limit and transient errors — not auth/budget.
Future<T> withRetry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 5,
  Duration initialDelay = const Duration(seconds: 1),
  bool retryOnAllErrors = false,
}) async {
  Object? lastError;
  StackTrace? lastStack;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      final isLastAttempt = attempt == maxAttempts - 1;
      final shouldRetry = retryOnAllErrors
          ? !_isNonRetryableError(e)
          : (_isRateLimitError(e) || _isTransientError(e));

      if (isLastAttempt || !shouldRetry) {
        Error.throwWithStackTrace(e, st);
      }

      final delay = initialDelay * (1 << attempt); // 1s → 2s → 4s → 8s
      AppLogger.w(
        'Gemini retry ${attempt + 1}/$maxAttempts after ${delay.inSeconds}s: $e',
        category: LogCategory.api,
      );
      await Future.delayed(delay);
    }
  }

  Error.throwWithStackTrace(
    lastError ?? Exception('Max retries reached for Gemini call'),
    lastStack ?? StackTrace.current,
  );
}

bool _isNonRetryableError(Object error) {
  if (error is ApiException) {
    return error.isAuthError || error.isBudgetExhausted;
  }
  return false;
}

bool _isRateLimitError(Object error) {
  if (error is ApiException) return error.isRateLimited;
  final msg = error.toString().toLowerCase();
  return msg.contains('busy') ||
      msg.contains('usage limit') ||
      msg.contains('rate limit') ||
      msg.contains('429') ||
      msg.contains('quota');
}

bool _isTransientError(Object error) {
  if (error is ApiException) return error.isTransient;
  if (error is TimeoutException || error is SocketException) return true;
  if (error is http.ClientException) return true;
  final msg = error.toString().toLowerCase();
  return msg.contains('timeout') ||
      msg.contains('connection') ||
      msg.contains('unavailable');
}

/// Thin HTTP client for the two backend endpoints the app uses.
class ApiClient {
  static Map<String, String> get _authHeaders =>
      ApiConfig.apiKey.isEmpty ? {} : {'X-API-Key': ApiConfig.apiKey};

  static Map<String, String> _patientHeaders({
    required String email,
    required String syncToken,
  }) =>
      {
        ..._authHeaders,
        'X-Patient-Email': email.trim().toLowerCase(),
        'X-Sync-Token': syncToken,
      };

  /// POST /chat — AI consultation. Backend currently maps both complexity
  /// levels to Gemini 1.5 Flash to avoid aggressive newer-model quotas.
  static Future<String> chat({
    required String userId,
    required String message,
    String complexity = 'simple',
  }) =>
      withRetry(() => _chatOnce(
            userId: userId,
            message: message,
            complexity: complexity,
          ));

  static Future<String> _chatOnce({
    required String userId,
    required String message,
    required String complexity,
  }) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/chat'),
          headers: {..._authHeaders, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'message': message,
            'complexity': complexity,
          }),
        )
        .timeout(const Duration(seconds: 60));

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['reply'] as String;
    throw ApiException(res.statusCode, _detail(body));
  }

  /// POST /analyze — medical analysis of a file (PDF or image) plus optional
  /// text logs. Always uses the complex model server-side. Returns the analysis.
  static Future<String> analyze({
    required String userId,
    required String filePath,
    String textLogs = '',
    String complexity = 'complex',
  }) =>
      withRetry(() => _analyzeOnce(
            userId: userId,
            filePath: filePath,
            textLogs: textLogs,
            complexity: complexity,
          ));

  static Future<String> _analyzeOnce({
    required String userId,
    required String filePath,
    required String textLogs,
    required String complexity,
  }) async {
    final filename = p.basename(filePath);
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/analyze'),
    )
      ..headers.addAll(_authHeaders)
      ..fields['user_id'] = userId
      ..fields['text_logs'] = textLogs
      ..fields['complexity'] = complexity
      ..files.add(await http.MultipartFile.fromPath(
        'pdf',
        filePath,
        filename: filename,
        contentType: _mediaTypeForPath(filePath),
      ));

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['analysis'] as String;
    throw ApiException(res.statusCode, _detail(body));
  }

  /// Gemini / Vertex reject `application/octet-stream` — map by extension.
  static MediaType _mediaTypeForPath(String filePath) {
    switch (p.extension(filePath).toLowerCase()) {
      case '.jpg':
      case '.jpeg':
        return MediaType('image', 'jpeg');
      case '.png':
        return MediaType('image', 'png');
      case '.gif':
        return MediaType('image', 'gif');
      case '.webp':
        return MediaType('image', 'webp');
      case '.heic':
        return MediaType('image', 'heic');
      case '.heif':
        return MediaType('image', 'heif');
      case '.pdf':
        return MediaType('application', 'pdf');
      case '.dcm':
      case '.dicom':
        return MediaType('application', 'dicom');
      default:
        // Meal photos from image_picker are almost always JPEG even when
        // the temp path has an unusual suffix.
        return MediaType('image', 'jpeg');
    }
  }

  static String _detail(Map<String, dynamic> body) =>
      body['detail']?.toString() ?? 'Request failed';

  /// GET /patient/exists — whether a history file exists for this email.
  static Future<bool> patientExists(String email) async {
    final res = await http
        .get(
          Uri.parse(
            '${ApiConfig.baseUrl}/patient/exists?email=${Uri.encodeQueryComponent(email.trim().toLowerCase())}',
          ),
          headers: _authHeaders,
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['exists'] as bool? ?? false;
    throw ApiException(res.statusCode, _detail(body));
  }

  /// GET /patient/history — download encrypted health history. Returns null if 404.
  static Future<Map<String, dynamic>?> getPatientHistory({
    required String email,
    required String syncToken,
  }) async {
    final res = await http
        .get(
          Uri.parse('${ApiConfig.baseUrl}/patient/history'),
          headers: _patientHeaders(email: email, syncToken: syncToken),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 404) return null;
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) return body;
    throw ApiException(res.statusCode, _detail(body));
  }

  /// PUT /patient/history — upload full health history for this email.
  static Future<void> putPatientHistory({
    required String email,
    required String syncToken,
    required Map<String, dynamic> payload,
  }) async {
    final res = await http
        .put(
          Uri.parse('${ApiConfig.baseUrl}/patient/history'),
          headers: {
            ..._patientHeaders(email: email, syncToken: syncToken),
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 200) return;
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    throw ApiException(res.statusCode, _detail(body));
  }
}
