import 'package:flutter/foundation.dart';

abstract final class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');
  static String? _customOrigin;

  static void setServerOrigin(String origin) {
    var clean = origin.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
      clean = 'http://$clean';
    }
    if (clean.endsWith('/api/v1')) {
      _customOrigin = clean.substring(0, clean.length - '/api/v1'.length);
    } else {
      _customOrigin = clean;
    }
  }

  static String get baseUrl {
    if (_customOrigin != null && _customOrigin!.isNotEmpty) {
      return '$_customOrigin/api/v1';
    }
    if (_envBaseUrl.trim().isNotEmpty) {
      return validateAndNormalizeUrl(_envBaseUrl);
    }
    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'http://192.168.1.18:8000/api/v1';
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      default:
        return 'http://127.0.0.1:8000/api/v1';
    }
  }

  static String get originUrl {
    if (_customOrigin != null && _customOrigin!.isNotEmpty) {
      return _customOrigin!;
    }
    final full = baseUrl;
    return full.endsWith('/api/v1')
        ? full.substring(0, full.length - '/api/v1'.length)
        : full;
  }

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  /// Validates and normalizes an API base URL.
  /// Ensures valid http/https scheme and host, prevents secret leakage,
  /// and strips trailing slashes to guarantee clean path composition.
  static String validateAndNormalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('API Base URL cannot be empty');
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw FormatException(
        'Invalid API Base URL: "$trimmed". Must be a valid HTTP or HTTPS URL with a valid host.',
      );
    }

    if (uri.userInfo.isNotEmpty) {
      throw const FormatException('API Base URL must not contain embedded user credentials');
    }

    var normalized = trimmed;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
