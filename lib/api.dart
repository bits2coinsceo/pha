import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'core/app_logger.dart';
import 'session_secret.dart';

/// HTTPS-only API base. Localhost is allowed for a dev server on the machine.
String _httpsApiBase(String raw) {
  final trimmed = raw.trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(trimmed);
  final host = uri?.host.toLowerCase() ?? '';
  final isLocal = host == 'localhost' || host == '127.0.0.1';
  if (uri == null ||
      uri.host.isEmpty ||
      (uri.scheme != 'https' && !(isLocal && uri.scheme == 'http'))) {
    throw StateError('PHA_API_BASE must use https');
  }
  return trimmed;
}

/// Configuration for the PHA backend (FastAPI + Vertex AI Gemini).
///
/// Compile-time values come from `--dart-define-from-file=dart_define.json`.
/// The JSON file is not bundled into the app, so the API key is not shipped
/// as a loose asset.
class ApiConfig {
  static const _baseUrlEnv = String.fromEnvironment(
    'PHA_API_BASE',
    defaultValue: 'https://api.pha-app.net',
  );
  static const _apiKeyEnv = String.fromEnvironment('PHA_API_KEY', defaultValue: '');

  static String baseUrl = _httpsApiBase(_baseUrlEnv);
  static String apiKey = _apiKeyEnv;

  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    baseUrl = _httpsApiBase(baseUrl);
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

  static Future<Map<String, String>> _sessionHeaders() async {
    final session = await SessionSecret.current();
    if (session == null) {
      throw ApiException(401, 'auth_required');
    }
    return _patientHeaders(email: session.email, syncToken: session.token);
  }

  static Future<String> _chatOnce({
    required String userId,
    required String message,
    required String complexity,
  }) async {
    final res = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/chat'),
          headers: {
            ...await _sessionHeaders(),
            'Content-Type': 'application/json',
          },
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
      ..headers.addAll(await _sessionHeaders())
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

  static Future<Map<String, dynamic>> _postAuth(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    AppLogger.i('POST $uri', category: LogCategory.auth);
    late http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: {
            ..._authHeaders,
            ...?extraHeaders,
            'Content-Type': 'application/json',
          },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e, st) {
      AppLogger.e(
        'POST $uri failed before a response',
        error: e,
        stackTrace: st,
        category: LogCategory.auth,
      );
      rethrow;
    }
    final raw = utf8.decode(res.bodyBytes);
    if (res.statusCode == 200) {
      AppLogger.i('POST $uri -> ${res.statusCode}', category: LogCategory.auth);
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
      return const {};
    }
      AppLogger.e(
      'POST $uri -> HTTP ${res.statusCode}',
      category: LogCategory.auth,
    );
    Map<String, dynamic> decoded = const {};
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) decoded = parsed;
    } catch (_) {}
    throw ApiException(res.statusCode, _detail(decoded));
  }

  static Future<void> sendRegistrationCode(String email) async {
    await _postAuth(
      '/api/auth/register-send-code',
      {'email': email.trim().toLowerCase()},
    );
  }

  static Future<String> verifyRegistrationCode({
    required String email,
    required String code,
  }) async {
    final body = await _postAuth(
      '/api/auth/register-verify',
      {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );
    final ticket = body['registration_ticket'] as String? ?? '';
    if (ticket.isEmpty) {
      throw ApiException(400, 'invalid_code');
    }
    return ticket;
  }

  static Future<({String syncToken, String userId})> registerAccount({
    required String email,
    required String password,
    required String userId,
    required String registrationTicket,
  }) async {
    final body = await _postAuth(
      '/api/auth/register-account',
      {
        'email': email.trim().toLowerCase(),
        'password': password,
        'user_id': userId,
        'registration_ticket': registrationTicket,
      },
    );
    return _sessionFrom(body);
  }

  static Future<({String syncToken, String userId})> openSession({
    required String email,
    required String password,
  }) async {
    final body = await _postAuth(
      '/api/auth/session',
      {
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return _sessionFrom(body);
  }

  static ({String syncToken, String userId}) _sessionFrom(Map<String, dynamic> body) {
    final token = body['sync_token'] as String? ?? '';
    if (token.isEmpty) {
      throw ApiException(401, 'invalid_credentials');
    }
    return (syncToken: token, userId: body['user_id'] as String? ?? '');
  }

  static Future<({String plan, String expiresAt, String codeId})> redeemPromo({
    required String code,
    required String deviceId,
  }) async {
    final body = await _postAuth(
      '/patient/promo',
      {'code': code.trim(), 'device_id': deviceId},
      extraHeaders: await _sessionHeaders(),
    );
    return (
      plan: body['plan'] as String? ?? '',
      expiresAt: body['expires_at'] as String? ?? '',
      codeId: body['code_id'] as String? ?? '',
    );
  }

  static Future<void> sendPasswordResetCode(String email) async {
    await _postAuth(
      '/api/auth/forgot-password-send-code',
      {'email': email.trim().toLowerCase()},
    );
  }

  static Future<void> verifyPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _postAuth(
      '/api/auth/forgot-password-verify',
      {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
  }
}
