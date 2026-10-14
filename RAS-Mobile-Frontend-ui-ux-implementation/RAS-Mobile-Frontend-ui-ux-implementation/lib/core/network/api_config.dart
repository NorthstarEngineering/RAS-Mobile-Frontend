import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Service addresses are independently configurable with --dart-define.
/// Android emulators reach the host through 10.0.2.2; physical devices should
/// provide the development machine's LAN address explicitly.
class ApiConfig {
  const ApiConfig._();

  static String get authBaseUrl =>
      _url(const String.fromEnvironment('RAS_AUTH_BASE_URL'), '9001');
  static String get branchBaseUrl =>
      _url(const String.fromEnvironment('RAS_BRANCH_BASE_URL'), '9002');
  static String get attendanceBaseUrl =>
      _url(const String.fromEnvironment('RAS_ATTENDANCE_BASE_URL'), '9003');

  static String _url(String configured, String port) {
    if (configured.trim().isNotEmpty) return configured.trim();
    final host = defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return 'http://$host:$port/api/v1';
  }
}
