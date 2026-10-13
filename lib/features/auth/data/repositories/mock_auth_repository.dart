import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  UserSession? _currentSession;

  static const List<UserSession> _presetUsers = [
    UserSession(
      id: 'EMP-1001',
      name: 'م. ألفاريز',
      email: 'm.alvarez@rms-ops.com',
      role: StaffRole.shiftLead,
      token: 'jwt_mock_token_lead_123',
      branchId: '104',
      branchName: 'الفرع الرئيسي - وسط البلد',
    ),
    UserSession(
      id: 'EMP-1002',
      name: 'ج. ميلر',
      email: 'j.miller@rms-ops.com',
      role: StaffRole.branchManager,
      token: 'jwt_mock_token_manager_456',
      branchId: '104',
      branchName: 'الفرع الرئيسي - وسط البلد',
    ),
  ];

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    // Simulate real network/hardware authorization latency
    await Future<void>.delayed(const Duration(milliseconds: 800));

    final user = _presetUsers.firstWhere(
      (u) =>
          u.email.toLowerCase() == identifier.toLowerCase() ||
          u.id.toLowerCase() == identifier.toLowerCase(),
      orElse: () => throw const FormatException(
        'بيانات غير صحيحة. متبقي محاولتان (2).',
      ),
    );

    // For demo purposes, any password with length >= 6 is valid
    if (password.length < 6) {
      throw const FormatException('كلمة المرور يجب أن لا تقل عن 6 أحرف');
    }

    _currentSession = user;
    return user;
  }

  @override
  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _currentSession = null;
  }

  @override
  Future<UserSession?> getCurrentSession() async {
    return _currentSession;
  }
}
