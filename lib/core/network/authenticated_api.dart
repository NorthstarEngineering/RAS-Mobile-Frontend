import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/auth/data/repositories/api_auth_repository.dart';

class AuthenticatedApi {
  AuthenticatedApi(this.auth, {http.Client? client})
    : _client = client ?? http.Client();

  final ApiAuthRepository auth;
  final http.Client _client;

  Future<dynamic> get(String path) => _send(
    () async => _client.get(
      Uri.parse('${auth.baseUrl}$path'),
      headers: await authHeaders,
    ),
  );

  Future<dynamic> post(String path, Map<String, dynamic> body) => _send(
    () async => _client.post(
      Uri.parse('${auth.baseUrl}$path'),
      headers: await authHeaders,
      body: jsonEncode(body),
    ),
  );

  Future<dynamic> patch(String path, Map<String, dynamic> body) => _send(
    () async => _client.patch(
      Uri.parse('${auth.baseUrl}$path'),
      headers: await authHeaders,
      body: jsonEncode(body),
    ),
  );

  Future<Map<String, String>> get authHeaders => auth.authHeaders();

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    var response = await request();
    if (response.statusCode == 401) {
      await auth.refreshForApi();
      response = await request();
    }
    final dynamic data = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map && data['error'] is Map
          ? '${(data['error'] as Map)['message'] ?? 'API request failed'}'
          : 'API request failed (${response.statusCode})';
      throw FormatException(message);
    }
    return data;
  }
}
