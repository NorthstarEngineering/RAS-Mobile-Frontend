import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession> login({
    required String identifier,
    required String password,
  });

  Future<void> logout();

  Future<UserSession?> getCurrentSession();

  Future<List<Map<String, dynamic>>> listAccounts();

  Future<Map<String, dynamic>> createAccount({
    required String name,
    required String email,
    required String password,
    required String role,
    String? branchId,
  });
}
