import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({FlutterSecureStorage? storage, http.Client? client})
    : _storage = storage ?? const FlutterSecureStorage(),
      _client = client ?? http.Client() {
    _api = ApiClient(
      baseUrl: ApiConfig.authBaseUrl,
      accessToken: _readAccessToken,
      refreshSession: _refreshSession,
      client: _client,
    );
  }

  static const _accessKey = 'ras.access_token';
  static const _refreshKey = 'ras.refresh_token';
  static const _expiresKey = 'ras.expires_at';
  static const _userKey = 'ras.user';
  final FlutterSecureStorage _storage;
  final http.Client _client;
  late final ApiClient _api;
  Future<bool>? _refreshInFlight;

  Future<String?> _readAccessToken() => _storage.read(key: _accessKey);
  Future<String?> getAccessToken() => _readAccessToken();
  Future<bool> refreshNow() => _refreshSession();

  @override
  Future<UserSession> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final data = await _api.post('/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid session response');
    }
    final session = _sessionFrom(data);
    await _saveSession(data);
    return session;
  }

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    final data = await _api.request(
      'POST',
      '/auth/login',
      authenticated: false,
      body: {'email': identifier.trim(), 'password': password},
    );
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid session response');
    }
    final session = _sessionFrom(data);
    await _saveSession(data);
    return session;
  }

  UserSession _sessionFrom(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is! Map<String, dynamic> ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String ||
        data['expires_at'] is! String) {
      throw const FormatException('Invalid session response');
    }
    final roleCode = user['role']?.toString().toUpperCase();
    final role = switch (roleCode) {
      'CEO' => StaffRole.ceo,
      'SUPPLY_MANAGER' => StaffRole.shiftLead,
      _ => StaffRole.branchManager,
    };
    return UserSession(
      id: user['id']?.toString() ?? '',
      name: user['name']?.toString() ?? '',
      email: user['email']?.toString() ?? '',
      role: role,
      token: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresAt: DateTime.tryParse(data['expires_at'] as String),
      mustChangePassword: user['must_change_password'] == true,
      branchId: user['branch_id']?.toString() ?? '',
      branchName: '',
    );
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    // Persist the rotated token pair and associated identity before exposing it.
    await _storage.write(
      key: _accessKey,
      value: data['access_token'] as String,
    );
    await _storage.write(
      key: _refreshKey,
      value: data['refresh_token'] as String,
    );
    await _storage.write(key: _expiresKey, value: data['expires_at'] as String);
    await _storage.write(key: _userKey, value: jsonEncode(data['user']));
  }

  Future<bool> _refreshSession() {
    return _refreshInFlight ??= _doRefresh().whenComplete(
      () => _refreshInFlight = null,
    );
  }

  Future<bool> _doRefresh() async {
    final refresh = await _storage.read(key: _refreshKey);
    if (refresh == null || refresh.isEmpty) {
      await _clearSession();
      return false;
    }
    try {
      final data = await _api.request(
        'POST',
        '/auth/refresh',
        authenticated: false,
        body: {'refresh_token': refresh},
      );
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Invalid refresh response');
      }
      await _saveSession(data);
      return true;
    } catch (_) {
      await _clearSession();
      return false;
    }
  }

  Future<void> _clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessKey),
      _storage.delete(key: _refreshKey),
      _storage.delete(key: _expiresKey),
      _storage.delete(key: _userKey),
    ]);
  }

  @override
  Future<UserSession?> getCurrentSession() async {
    final rawUser = await _storage.read(key: _userKey);
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    final expires = await _storage.read(key: _expiresKey);
    if (rawUser == null || access == null || refresh == null || expires == null) {
      return null;
    }
    final expiry = DateTime.tryParse(expires);
    if (expiry == null) {
      await _clearSession();
      return null;
    }
    if (!expiry.isAfter(
          DateTime.now().toUtc().add(const Duration(seconds: 20)),
        ) &&
        !await _refreshSession()) {
      return null;
    }
    final latestUser = await _storage.read(key: _userKey);
    final latestAccess = await _storage.read(key: _accessKey);
    final latestRefresh = await _storage.read(key: _refreshKey);
    final latestExpiry = await _storage.read(key: _expiresKey);
    if (latestUser == null ||
        latestAccess == null ||
        latestRefresh == null ||
        latestExpiry == null) {
      return null;
    }
    final user = jsonDecode(latestUser) as Map<String, dynamic>;
    return _sessionFrom({
      'user': user,
      'access_token': latestAccess,
      'refresh_token': latestRefresh,
      'expires_at': latestExpiry,
    });
  }

  @override
  Future<void> logout() async {
    final refresh = await _storage.read(key: _refreshKey);
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await _api.request(
          'POST',
          '/auth/logout',
          authenticated: false,
          body: {'refresh_token': refresh},
        );
      }
    } catch (_) {
      // Local credentials are always cleared after an explicit logout.
    } finally {
      await _clearSession();
    }
  }
}
