import '../entities/user_session.dart';

abstract class AuthRepository {
  Future<UserSession> login({
    required String identifier,
    required String password,
  });

  Future<void> logout();

  Future<UserSession> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<UserSession?> getCurrentSession();
}
