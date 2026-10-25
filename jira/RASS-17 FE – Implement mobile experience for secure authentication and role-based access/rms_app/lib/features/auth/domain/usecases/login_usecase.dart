import '../entities/user_session.dart';
import '../repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  AuthRepository get repository => _repository;

  Future<UserSession> call({
    required String identifier,
    required String password,
  }) {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      throw const FormatException('يرجى إدخال رقم الموظف أو البريد الإلكتروني');
    }
    if (password.trim().isEmpty) {
      throw const FormatException('يرجى إدخال كلمة المرور');
    }

    return _repository.login(
      identifier: cleanId,
      password: password,
    );
  }
}
