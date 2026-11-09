import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository({
    http.Client? client,
    SharedPreferences? preferences,
    this.baseUrl = const String.fromEnvironment(
      'RAS_API_BASE_URL',
      defaultValue:
          'https://1gc2i9l29g.execute-api.eu-west-3.amazonaws.com/dev',
    ),
  }) : _client = client ?? http.Client(),
       _preferences = preferences;

  final http.Client _client;
  final SharedPreferences? _preferences;
  final String baseUrl;
  UserSession? _currentSession;

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'email': identifier, 'password': password}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw FormatException(
        _message(data, 'Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ø¯Ø®ÙˆÙ„ ØºÙŠØ± ØµØ­ÙŠØ­Ø©'),
      );
    }
    final session = _sessionFrom(data);
    _currentSession = session;
    await _saveSession(session);
    return session;
  }

  @override
  Future<void> logout() async {
    final session = _currentSession;
    _currentSession = null;
    final preferences = _preferences;
    if (preferences != null) {
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith('session.'),
      )) {
        await preferences.remove(key);
      }
    }
    if (session != null && session.refreshToken.isNotEmpty) {
      final response = await _client.post(
        Uri.parse('$baseUrl/api/v1/auth/logout'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'refresh_token': session.refreshToken}),
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw FormatException(
          _message(_decode(response), 'ØªØ¹Ø°Ø± Ø¥Ù†Ù‡Ø§Ø¡ Ø§Ù„Ø¬Ù„Ø³Ø©'),
        );
      }
    }
  }

  @override
  Future<UserSession?> getCurrentSession() async {
    if (_currentSession != null) return _currentSession;
    final preferences = _preferences;
    if (preferences == null) return null;
    final values = <String, String>{
      for (final key in preferences.getKeys())
        if (key.startsWith('session.'))
          key.substring('session.'.length): preferences.getString(key) ?? '',
    };
    if (values.isEmpty) return null;
    _currentSession = UserSession.fromStorage(values);
    return _currentSession;
  }

  Future<void> persistSession(UserSession session) async {
    _currentSession = session;
    await _saveSession(session);
  }

  Future<void> _saveSession(UserSession session) async {
    final preferences = _preferences;
    if (preferences == null) return;
    for (final entry in session.toStorage().entries) {
      await preferences.setString('session.${entry.key}', entry.value);
    }
  }

  Future<Map<String, String>> authHeaders() async {
    var session = await getCurrentSession();
    if (session == null) {
      throw const FormatException(
        'Ø§Ù†ØªÙ‡Øª Ø§Ù„Ø¬Ù„Ø³Ø©ØŒ ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù…Ø¬Ø¯Ø¯Ø§Ù‹',
      );
    }

    if (session.token.isEmpty) {
      await _refreshSession();
      session = await getCurrentSession();
      if (session == null || session.token.isEmpty) {
        throw const FormatException(
          'Ø§Ù†ØªÙ‡Øª Ø§Ù„Ø¬Ù„Ø³Ø©ØŒ ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù…Ø¬Ø¯Ø¯Ø§Ù‹',
        );
      }
    }
    return {
      'content-type': 'application/json',
      'authorization': 'Bearer ${session.token}',
    };
  }

  Future<void> refreshForApi() => _refreshSession();

  Future<void> _refreshSession() async {
    final session = await getCurrentSession();
    if (session == null || session.refreshToken.isEmpty) {
      await _clearSession();
      throw const FormatException(
        'Ø§Ù†ØªÙ‡Øª Ø§Ù„Ø¬Ù„Ø³Ø©ØŒ ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù…Ø¬Ø¯Ø¯Ø§Ù‹',
      );
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/auth/refresh'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'refresh_token': session.refreshToken}),
    );
    final data = _decode(response);
    if (response.statusCode != 200) {
      await _clearSession();
      throw FormatException(
        _message(
          data,
          'Ø§Ù†ØªÙ‡Øª Ø§Ù„Ø¬Ù„Ø³Ø©ØŒ ÙŠØ±Ø¬Ù‰ ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù…Ø¬Ø¯Ø¯Ø§Ù‹',
        ),
      );
    }
    final refreshed = _sessionFrom(data);
    _currentSession = refreshed;
    await _saveSession(refreshed);
  }

  Future<void> _clearSession() async {
    _currentSession = null;
    final preferences = _preferences;
    if (preferences != null) {
      for (final key in preferences.getKeys().where(
        (key) => key.startsWith('session.'),
      )) {
        await preferences.remove(key);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> listAccounts() async {
    var response = await _client.get(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: await authHeaders(),
    );
    if (response.statusCode == 401) {
      await _refreshSession();
      response = await _client.get(
        Uri.parse('$baseUrl/api/v1/users'),
        headers: await authHeaders(),
      );
    }
    final data = _decode(response);
    if (response.statusCode != 200) {
      throw FormatException(
        _message(data, 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„Ø­Ø³Ø§Ø¨Ø§Øª'),
      );
    }
    final users = data['users'];
    if (users is! List) return const [];
    return users
        .whereType<Map>()
        .map(
          (user) => {
            'name': '${user['name'] ?? ''}',
            'email': '${user['email'] ?? ''}',
            'role': '${user['role'] ?? ''}',
            'branch': '${user['branch_id'] ?? ''}',
            'isActive': user['is_active'] == true,
          },
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> createAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
  }) async {
    var response = await _client.post(
      Uri.parse('$baseUrl/api/v1/users'),
      headers: await authHeaders(),
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
      }),
    );
    if (response.statusCode == 401) {
      await _refreshSession();
      response = await _client.post(
        Uri.parse('$baseUrl/api/v1/users'),
        headers: await authHeaders(),
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
          if (branchId != null && branchId.isNotEmpty) 'branch_id': branchId,
        }),
      );
    }
    final data = _decode(response);
    if (response.statusCode != 201 && response.statusCode != 200) {
      throw FormatException(_message(data, 'ØªØ¹Ø°Ø± Ø¥Ù†Ø´Ø§Ø¡ Ø§Ù„Ø­Ø³Ø§Ø¨'));
    }
    return (data['user'] as Map?)?.cast<String, dynamic>() ?? data;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _message(Map<String, dynamic> data, String fallback) {
    final error = data['error'];
    if (error is Map && error['message'] is String) {
      return error['message'] as String;
    }
    return fallback;
  }

  UserSession _sessionFrom(Map<String, dynamic> data) {
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    return UserSession(
      id: '${user['id'] ?? ''}',
      name: '${user['name'] ?? user['email'] ?? ''}',
      email: '${user['email'] ?? ''}',
      role: _role('${user['role'] ?? 'CEO'}'),
      token: '${data['access_token'] ?? ''}',
      refreshToken: '${data['refresh_token'] ?? ''}',
      branchId: '${user['branch_id'] ?? ''}',
      branchName: '${user['branch_name'] ?? ''}',
    );
  }

  StaffRole _role(String role) {
    switch (role.toUpperCase()) {
      case 'BRANCH_MANAGER':
      case 'BM':
        return StaffRole.branchManager;
      case 'SHIFT_LEAD':
        return StaffRole.shiftLead;
      case 'CASHIER':
        return StaffRole.cashier;
      default:
        return StaffRole.ceo;
    }
  }
}
