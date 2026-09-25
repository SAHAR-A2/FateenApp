import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Thrown for any failure calling the FATEEN backend, with enough
/// structure for screens to distinguish "not found" from other failures
/// without re-parsing raw HTTP responses in every screen (see the
/// Architecture Audit's §I3 "structured errors" requirement).
class FateenApiException implements Exception {
  final int? statusCode;
  final String message;

  FateenApiException(this.message, {this.statusCode});

  bool get isNotFound => statusCode == 404;

  @override
  String toString() => 'FateenApiException($statusCode): $message';
}

/// Centralized HTTP client for the FATEEN backend.
///
/// Base URL is configurable at build time via
/// `--dart-define=FATEEN_API_BASE_URL=https://api.fateen.example` (defaults
/// to `http://localhost:8000` for local development). It must NOT be
/// hardcoded per-screen.
///
/// SECURITY NOTE (updated after the auth-hardening pass):
/// This client attaches the signed-in user's Firebase ID token as a
/// Bearer token when one is available. As of this hardening pass, the
/// FATEEN backend DOES verify this token on the two routes that receive
/// allergy/health context
/// (POST .../compatibility, POST .../alternatives) -- see
/// app/core/auth.py -- and rejects requests with 401 if verification
/// fails. HOWEVER, that verification is itself only active on a backend
/// deployment where GOOGLE_APPLICATION_CREDENTIALS is configured with a
/// real Firebase service-account credential; this has NOT been tested
/// against a real Firebase project in this environment (no network/
/// credentials available). Until that is confirmed on a real deployment,
/// treat 401 handling here as necessary but not yet proven end-to-end.
class ApiClient {
  ApiClient({String? baseUrl, http.Client? httpClient})
      : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const String _configuredBaseUrl = String.fromEnvironment(
    'FATEEN_API_BASE_URL',
    defaultValue: '',
  );
  static const bool _sameOriginApi = bool.fromEnvironment(
    'FATEEN_API_SAME_ORIGIN',
    defaultValue: false,
  );

  static String get _defaultBaseUrl => _configuredBaseUrl.isNotEmpty
      ? _configuredBaseUrl
      : (kIsWeb && _sameOriginApi && Uri.base.host.isNotEmpty
          ? Uri.base.origin
          : 'http://localhost:8000');

  // Cloud Postgres may take about a minute to resume after an idle period.
  // The backend's connect/acquire/statement limits are bounded below this.
  static const Duration _timeout = Duration(seconds: 75);

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (_) {
      // Not signed in, or token retrieval failed -- proceed
      // unauthenticated. The backend does not require this yet (see the
      // class-level security note above).
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    try {
      final response = await _client
          .get(uri, headers: await _headers())
          .timeout(_timeout);
      return _decode(response);
    } on SocketException {
      throw FateenApiException('تعذّر الاتصال بخادم فطين، تحقق من الإنترنت');
    } on http.ClientException {
      throw FateenApiException('تعذّر الاتصال بخادم فطين');
    } on TimeoutException {
      throw FateenApiException('تأخر رد قاعدة البيانات، أعد المحاولة بعد قليل');
    }
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    try {
      final response = await _client
          .post(uri, headers: await _headers(), body: jsonEncode(body ?? {}))
          .timeout(_timeout);
      return _decode(response);
    } on SocketException {
      throw FateenApiException('تعذّر الاتصال بخادم فطين، تحقق من الإنترنت');
    } on http.ClientException {
      throw FateenApiException('تعذّر الاتصال بخادم فطين');
    } on TimeoutException {
      throw FateenApiException('تأخر رد قاعدة البيانات، أعد المحاولة بعد قليل');
    }
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode == 404) {
      throw FateenApiException('العنصر غير موجود', statusCode: 404);
    }
    if (response.statusCode == 401) {
      throw FateenApiException(
        'يلزم تسجيل الدخول لعرض نتيجة التوافق',
        statusCode: 401,
      );
    }
    if (response.statusCode >= 400) {
      String message = 'حدث خطأ في خادم فطين (${response.statusCode})';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['detail'] is String) {
          message = decoded['detail'] as String;
        }
      } catch (_) {
        // Non-JSON error body -- keep the generic message rather than
        // surfacing raw server internals to the user (audit §12).
      }
      throw FateenApiException(message, statusCode: response.statusCode);
    }
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void dispose() => _client.close();
}
