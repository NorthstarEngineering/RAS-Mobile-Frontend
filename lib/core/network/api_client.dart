import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_response.dart';
export 'api_response.dart';

typedef SessionExpiredCallback = void Function();

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    this.onSessionExpired,
  })  : _client = client ?? http.Client(),
        _explicitBaseUrl = baseUrl != null
            ? ApiConfig.validateAndNormalizeUrl(baseUrl)
            : null;

  final http.Client _client;
  final String? _explicitBaseUrl;
  String? _authToken;
  SessionExpiredCallback? onSessionExpired;
  bool _sessionExpiredNotified = false;

  String get baseUrl => _explicitBaseUrl ?? ApiConfig.baseUrl;
  String? get authToken => _authToken;
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  void setAuthToken(String? token) {
    final trimmed = token?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _authToken = null;
    } else {
      _authToken = trimmed;
      _sessionExpiredNotified = false;
    }
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Map<String, String> get defaultHeaders => _buildHeaders(null);

  Map<String, String> _buildHeaders(Map<String, String>? requestHeaders) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_authToken != null && _authToken!.isNotEmpty) {
      final authHeader = _authToken!.startsWith('Bearer ')
          ? _authToken!
          : 'Bearer $_authToken';
      headers['Authorization'] = authHeader;
    }

    if (requestHeaders != null && requestHeaders.isNotEmpty) {
      for (final entry in requestHeaders.entries) {
        if (entry.key.toLowerCase() == 'authorization') {
          headers.removeWhere((k, _) => k.toLowerCase() == 'authorization');
          if (entry.value.trim().isNotEmpty) {
            headers[entry.key] = entry.value;
          }
        } else {
          headers[entry.key] = entry.value;
        }
      }
    }

    return headers;
  }

  bool _hasNonEmptyAuthToken(Map<String, String> headers) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == 'authorization') {
        final val = entry.value.trim();
        if (val.isEmpty ||
            val.toLowerCase() == 'bearer' ||
            val.toLowerCase() == 'bearer null') {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  Uri _uri(String path) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$cleanPath');
  }

  Future<ApiResponse<dynamic>> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    final finalHeaders = _buildHeaders(headers);
    return _sendRequest(
      () => _client.get(
        _uri(path),
        headers: finalHeaders,
      ),
      path: path,
      tokenSent: _hasNonEmptyAuthToken(finalHeaders),
    );
  }

  Future<ApiResponse<dynamic>> post(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final finalHeaders = _buildHeaders(headers);
    return _sendRequest(
      () => _client.post(
        _uri(path),
        headers: finalHeaders,
        body: body != null ? jsonEncode(body) : null,
      ),
      path: path,
      tokenSent: _hasNonEmptyAuthToken(finalHeaders),
    );
  }

  Future<ApiResponse<dynamic>> put(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final finalHeaders = _buildHeaders(headers);
    return _sendRequest(
      () => _client.put(
        _uri(path),
        headers: finalHeaders,
        body: body != null ? jsonEncode(body) : null,
      ),
      path: path,
      tokenSent: _hasNonEmptyAuthToken(finalHeaders),
    );
  }

  Future<ApiResponse<dynamic>> patch(
    String path, {
    dynamic body,
    Map<String, String>? headers,
  }) async {
    final finalHeaders = _buildHeaders(headers);
    return _sendRequest(
      () => _client.patch(
        _uri(path),
        headers: finalHeaders,
        body: body != null ? jsonEncode(body) : null,
      ),
      path: path,
      tokenSent: _hasNonEmptyAuthToken(finalHeaders),
    );
  }

  Future<ApiResponse<dynamic>> delete(
    String path, {
    Map<String, String>? headers,
  }) async {
    final finalHeaders = _buildHeaders(headers);
    return _sendRequest(
      () => _client.delete(
        _uri(path),
        headers: finalHeaders,
      ),
      path: path,
      tokenSent: _hasNonEmptyAuthToken(finalHeaders),
    );
  }

  Future<ApiResponse<dynamic>> _sendRequest(
    Future<http.Response> Function() action, {
    String? path,
    bool tokenSent = false,
  }) async {
    try {
      final response = await action().timeout(ApiConfig.connectTimeout);
      return _parseResponse(response, path: path, tokenSent: tokenSent);
    } on TimeoutException {
      throw NetworkException(
        'انتهت مهلة الاتصال بالخادم (${ApiConfig.connectTimeout.inSeconds} ثوانٍ)',
        408,
      );
    } on http.ClientException catch (e) {
      throw NetworkException('فشل الاتصال بالخادم: ${e.message}', null);
    } on NetworkException {
      rethrow;
    } catch (e) {
      throw NetworkException('خطأ غير متوقع في الشبكة: $e', null);
    }
  }

  static final RegExp _bearerRegex = RegExp(
    r'Bearer\s+[A-Za-z0-9\-_.~+/=]+',
    caseSensitive: false,
  );
  static final RegExp _secretFieldRegex = RegExp(
    r'"?(password|secret|token|access_token|refresh_token|authorization)"?\s*[:=]\s*"?[^",\s}]+"?',
    caseSensitive: false,
  );

  static String _sanitize(String text) {
    var sanitized = text.replaceAllMapped(
      _bearerRegex,
      (_) => 'Bearer [REDACTED]',
    );
    sanitized = sanitized.replaceAllMapped(
      _secretFieldRegex,
      (m) => '${m.group(1)}: [REDACTED]',
    );
    return sanitized;
  }

  String _extractErrorMessage(http.Response response) {
    final statusCode = response.statusCode;
    if (response.body.trim().isEmpty) {
      return 'استجابة فارغة من الخادم (رمز الحالة $statusCode)';
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return _sanitize(detail.trim());
        } else if (detail is List && detail.isNotEmpty) {
          final items = detail.map((item) {
            if (item is Map) {
              final msg = item['msg'] ?? item['message'];
              final loc = item['loc'];
              if (loc is List && loc.isNotEmpty) {
                return '${loc.last}: $msg';
              }
              return msg?.toString() ?? item.toString();
            }
            return item.toString();
          }).join(', ');
          return _sanitize(items);
        }

        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _sanitize(message.trim());
        }

        final error = decoded['error'];
        if (error is String && error.trim().isNotEmpty) {
          return _sanitize(error.trim());
        } else if (error is Map) {
          final errMessage = error['message'] ?? error['detail'];
          if (errMessage != null) {
            return _sanitize(errMessage.toString());
          }
        }

        final errors = decoded['errors'];
        if (errors is List && errors.isNotEmpty) {
          return _sanitize(errors.map((e) => e.toString()).join(', '));
        }
      }
    } catch (_) {
      // Body is not JSON
    }

    var rawBody = response.body.trim();
    if (rawBody.length > 250) {
      rawBody = '${rawBody.substring(0, 250)}...';
    }
    return _sanitize('خطأ من الخادم ($statusCode): $rawBody');
  }

  bool _isLoginPath(String? path) {
    if (path == null) return false;
    final normalized = path.toLowerCase().trim();
    return normalized == '/auth/login' ||
        normalized == 'auth/login' ||
        normalized == '/login' ||
        normalized == 'login' ||
        normalized.endsWith('/auth/login') ||
        normalized.endsWith('/login');
  }

  ApiResponse<dynamic> _parseResponse(
    http.Response response, {
    String? path,
    bool tokenSent = false,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return const ApiResponse(success: true);
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return ApiResponse.fromJson(decoded, (data) => data);
      }
      return ApiResponse(success: true, data: decoded);
    } else {
      final message = _extractErrorMessage(response);
      dynamic errorDetails;
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) {
          errorDetails =
              decoded['detail'] ?? decoded['errors'] ?? decoded['error'];
        }
      } catch (_) {}

      if (response.statusCode == 401) {
        final isLogin = _isLoginPath(path);
        // Expiry handler must trigger ONLY when an actual nonempty token was sent for a protected request,
        // and NOT on unauthenticated bootstrap probes or bad login attempts.
        if (!isLogin && tokenSent) {
          clearAuthToken();
          if (!_sessionExpiredNotified) {
            _sessionExpiredNotified = true;
            try {
              onSessionExpired?.call();
            } catch (_) {}
          }
        }
      }

      throw NetworkException(message, response.statusCode, errorDetails);
    }
  }

  void close() {
    _client.close();
  }
}
