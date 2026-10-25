import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    AuthRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  })  : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : null),
        _remoteDataSource = remoteDataSource ??
            AuthRemoteDataSource(
              apiClient: apiClient ??
                  (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient()),
            );

  final AuthRemoteDataSource _remoteDataSource;
  final ApiClient? _apiClient;
  UserSession? _currentSession;

  final List<Map<String, dynamic>> _cachedAccounts = [];

  List<Map<String, dynamic>> get cachedAccounts =>
      List.unmodifiable(_cachedAccounts);

  @override
  Future<UserSession> login({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim();
    if (cleanId.isEmpty) {
      throw const FormatException('يرجى إدخال اسم المستخدم أو البريد الإلكتروني');
    }
    if (password.length < 6) {
      throw const FormatException('كلمة المرور يجب أن لا تقل عن 6 أحرف');
    }

    try {
      final data = await _remoteDataSource.login(
        identifier: cleanId,
        password: password,
      );
      final session = _mapJsonToSession(data);
      _currentSession = session;
      _remoteDataSource.setAuthToken(session.token);
      _apiClient?.setAuthToken(session.token);
      return session;
    } catch (e) {
      if (e is FormatException) {
        rethrow;
      }
      final msg = e.toString().replaceAll('Exception: ', '').replaceAll('NetworkException: ', '');
      throw FormatException(msg.isNotEmpty ? msg : 'بيانات الدخول غير صحيحة');
    }
  }

  @override
  Future<void> logout() async {
    final oldToken = _currentSession?.token;
    _currentSession = null;
    _remoteDataSource.setAuthToken(null);
    _apiClient?.clearAuthToken();
    try {
      await _remoteDataSource.logout(token: oldToken);
    } catch (_) {
      // Offline fallback
    }
  }

  @override
  Future<UserSession?> getCurrentSession() async {
    if (_currentSession != null) return _currentSession;

    // Fast local path: if cached token is empty/missing, return null locally without network lookup.
    // NEVER fabricate authenticated identity.
    final token = _currentSession?.token ?? _apiClient?.authToken;
    if (token == null || token.trim().isEmpty) {
      return null;
    }

    try {
      final data = await _remoteDataSource.getCurrentSession(token: token);
      if (data != null) {
        _currentSession = _mapJsonToSession(data);
      }
    } catch (_) {
      // Offline fallback
    }
    return _currentSession;
  }

  // CEO Account Management Methods
  Future<List<Map<String, dynamic>>> getAccounts() async {
    final remoteAccounts = await _remoteDataSource.getUsers(token: _currentSession?.token);
    _cachedAccounts
      ..clear()
      ..addAll(remoteAccounts.map(_normalizeAccountMap));
    return List<Map<String, dynamic>>.from(_cachedAccounts);
  }

  Future<void> toggleAccountStatus({
    required String email,
    required bool isActive,
    String? id,
  }) async {
    final targetId = id ?? email;
    await _remoteDataSource.updateUserStatus(
      targetId.toString(),
      isActive,
      token: _currentSession?.token,
    );
    final index = _cachedAccounts.indexWhere(
      (acc) =>
          (acc['email'] as String).toLowerCase() == email.toLowerCase() ||
          (id != null && acc['id'] == id),
    );
    if (index >= 0) {
      _cachedAccounts[index]['isActive'] = isActive;
    }
  }

  Future<void> createAccount(Map<String, dynamic> accountData) async {
    final token = _currentSession?.token;
    final res = await _remoteDataSource.createUser(accountData, token: token);
    final normalized = _normalizeAccountMap(res.isNotEmpty ? res : accountData);
    _cachedAccounts.removeWhere(
      (acc) => acc['id'] == normalized['id'] || acc['email'] == normalized['email'],
    );
    _cachedAccounts.add(normalized);
  }

  Future<void> updateAccount({
    required String id,
    required Map<String, dynamic> updateData,
  }) async {
    final token = _currentSession?.token;
    final res = await _remoteDataSource.updateUser(id, updateData, token: token);
    final normalized = _normalizeAccountMap(res.isNotEmpty ? res : updateData);
    final index = _cachedAccounts.indexWhere((acc) => acc['id'] == id);
    if (index >= 0) {
      _cachedAccounts[index] = normalized;
    } else {
      _cachedAccounts.add(normalized);
    }
  }

  Future<void> deleteAccount({required String id}) async {
    final token = _currentSession?.token;
    await _remoteDataSource.deleteUser(id, token: token);
    _cachedAccounts.removeWhere((acc) => acc['id'] == id);
  }

  // Password Recovery & Management
  Future<Map<String, dynamic>> forgotPassword(
    String identifier, {
    String method = 'sms',
  }) async {
    return _remoteDataSource.forgotPassword(identifier.trim(), method: method);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String otpCode,
    String? otpId,
  }) async {
    return _remoteDataSource.verifyOtp(
      identifier: identifier.trim(),
      otpCode: otpCode.trim(),
      otpId: otpId,
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String resetToken,
    required String newPassword,
    String? confirmPassword,
  }) async {
    return _remoteDataSource.resetPassword(
      identifier: identifier.trim(),
      resetToken: resetToken.trim(),
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
    bool logoutOtherDevices = true,
  }) async {
    return _remoteDataSource.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
      logoutOtherDevices: logoutOtherDevices,
      token: _currentSession?.token,
    );
  }

  // Metrics Fetchers
  Future<Map<String, dynamic>?> getCeoMetrics() async {
    return _remoteDataSource.getCeoMetrics(token: _currentSession?.token);
  }

  Future<Map<String, dynamic>?> getBranchMetrics(String branchId) async {
    return _remoteDataSource.getBranchMetrics(branchId, token: _currentSession?.token);
  }

  Future<Map<String, dynamic>?> getSupplyMetrics() async {
    return _remoteDataSource.getSupplyMetrics(token: _currentSession?.token);
  }

  Map<String, dynamic> _normalizeAccountMap(Map<String, dynamic> raw) {
    return {
      'id': (raw['id'] ?? raw['user_id'] ?? '').toString(),
      'name': (raw['name'] ?? raw['full_name_ar'] ?? '').toString(),
      'email': (raw['email'] ?? raw['identifier'] ?? '').toString(),
      'role': (raw['role'] ?? '').toString(),
      'roleArabic': (raw['roleArabic'] ?? raw['role_arabic'] ?? '').toString(),
      'branch': (raw['branch'] ?? raw['branchName'] ?? raw['branch_name'] ?? 'الفرع الرئيسي').toString(),
      'branchId': (raw['branchId'] ?? raw['branch_id'] ?? '').toString(),
      'isActive': raw['isActive'] ?? (raw['is_active'] == 1 || raw['is_active'] == true),
    };
  }

  UserSession _mapJsonToSession(Map<String, dynamic> json) {
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;

    final token = (json['token'] ??
            json['access_token'] ??
            userMap['token'] ??
            userMap['access_token'] ??
            '')
        .toString();

    if (token.isEmpty) {
      throw const FormatException('رمز المصادقة غير متوفر في استجابة الخادم');
    }

    final roleStr = (userMap['role'] ?? json['role'] ?? '').toString();
    final role = _parseStaffRole(roleStr);

    return UserSession(
      id: (userMap['id'] ?? userMap['user_id'] ?? json['id'] ?? '').toString(),
      name: (userMap['name'] ??
              userMap['full_name_ar'] ??
              userMap['username'] ??
              json['name'] ??
              '')
          .toString(),
      email: (userMap['email'] ??
              userMap['identifier'] ??
              json['email'] ??
              '')
          .toString(),
      role: role,
      token: token,
      branchId: (userMap['branchId'] ??
              userMap['branch_id'] ??
              json['branchId'] ??
              '104')
          .toString(),
      branchName: (userMap['branchName'] ??
              userMap['branch_name'] ??
              json['branchName'] ??
              'الفرع الرئيسي - وسط البلد')
          .toString(),
    );
  }

  static StaffRole _parseStaffRole(String roleStr) {
    final clean = roleStr.toLowerCase().trim();
    for (final r in StaffRole.values) {
      if (r.code == clean || r.name == clean || r.titleArabic == roleStr) {
        return r;
      }
    }
    if (clean.contains('ceo') || clean.contains('تنفيذي')) {
      return StaffRole.ceo;
    }
    if (clean.contains('manager') || clean.contains('مدير')) {
      return StaffRole.branchManager;
    }
    if (clean.contains('cashier') || clean.contains('صندوق')) {
      return StaffRole.cashier;
    }
    return StaffRole.shiftLead;
  }
}

