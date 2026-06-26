import 'dart:convert';

import 'package:http/http.dart' as http;

/// Configuration for the PHA backend (FastAPI + Vertex AI Gemini).
///
/// Both values are read from compile-time `--dart-define`s so the API key never
/// has to live in source/git. Provide them when running/building, e.g.:
///
///   flutter run --dart-define-from-file=dart_define.json
///
/// See `API.md` and `backend/README.md` for what the backend exposes.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'PHA_API_BASE',
    defaultValue: 'http://49.13.66.150:8080',
  );

  /// Shared secret sent as `X-API-Key`. Empty → header omitted (backend must
  /// then also run without API_KEY, otherwise requests get 401).
  static const apiKey = String.fromEnvironment('PHA_API_KEY', defaultValue: '');
}

/// Error carrying the backend's HTTP status + `detail` message.
/// Status 402 means the user's credit budget is exhausted.
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  bool get isBudgetExhausted => status == 402;

  @override
  String toString() => message;
}

/// Thin HTTP client for the two backend endpoints the app uses.
class ApiClient {
  static Map<String, String> get _authHeaders =>
      ApiConfig.apiKey.isEmpty ? {} : {'X-API-Key': ApiConfig.apiKey};

  /// POST /chat — AI consultation. `complexity`: 'simple' (gemini-2.5-flash)
  /// or 'complex' (gemini-3.5-flash). Returns the model's reply text.
  static Future<String> chat({
    required String userId,
    required String message,
    String complexity = 'simple',
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
  }) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/analyze'),
    )
      ..headers.addAll(_authHeaders)
      ..fields['user_id'] = userId
      ..fields['text_logs'] = textLogs
      ..fields['complexity'] = complexity
      ..files.add(await http.MultipartFile.fromPath('pdf', filePath));

    final streamed = await req.send().timeout(const Duration(seconds: 120));
    final res = await http.Response.fromStream(streamed);

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if (res.statusCode == 200) return body['analysis'] as String;
    throw ApiException(res.statusCode, _detail(body));
  }

  static String _detail(Map<String, dynamic> body) =>
      body['detail']?.toString() ?? 'Request failed';
}
