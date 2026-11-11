import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/repositories/api_auth_repository.dart';

class AuthenticatedApi {
  AuthenticatedApi(this.auth, {http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? auth.baseUrl).replaceFirst(RegExp(r'/+$'), '');

  final ApiAuthRepository auth;
  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> get(String path) => _send(
    () async =>
        _client.get(Uri.parse('$_baseUrl$path'), headers: await authHeaders),
  );

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
    () async => _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: await authHeaders,
      body: jsonEncode(body),
    ),
  );

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send(
    () async => _client.patch(
      Uri.parse('$_baseUrl$path'),
      headers: await authHeaders,
      body: jsonEncode(body),
    ),
  );

  Future<Map<String, String>> get authHeaders => auth.authHeaders();

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    var response = await request().timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) {
      await auth.refreshForApi();
      response = await request().timeout(const Duration(seconds: 20));
    }
    final dynamic data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map && data['error'] is Map
          ? '${(data['error'] as Map)['message'] ?? 'API request failed'}'
          : 'API request failed (${response.statusCode})';
      throw ApiException(response.statusCode, message);
    }
    return data;
  }
}

class ApiException extends FormatException {
  const ApiException(this.statusCode, String message) : super(message);
  final int statusCode;
}
