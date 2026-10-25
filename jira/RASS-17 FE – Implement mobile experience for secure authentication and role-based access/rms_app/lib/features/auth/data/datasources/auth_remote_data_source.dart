import '../../../../core/di/service_locator.dart';
import '../../../../core/network/api_client.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({ApiClient? apiClient})
      : _apiClient = apiClient ??
            (sl.isRegistered<ApiClient>() ? sl<ApiClient>() : ApiClient());

  final ApiClient _apiClient;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
    try {
      final dynamic client = _apiClient;
      if (token != null && token.isNotEmpty) {
        client.setAuthToken(token);
      } else {
        client.clearAuthToken();
      }
    } catch (_) {}
  }

  Map<String, String>? _buildHeaders(String? overrideToken) {
    final token = overrideToken ?? _authToken;
    if (token != null && token.isNotEmpty) {
      return {'Authorization': 'Bearer $token'};
    }
    return null;
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {
        'identifier': identifier,
        'password': password,
      },
    );
    if (response.success && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final token = data['token'] ?? data['access_token'];
      if (token is String && token.isNotEmpty) {
        setAuthToken(token);
      }
      return data;
    }
    throw NetworkException(response.message ?? 'استجابة غير صالحة من خادم المصادقة');
  }

  Future<void> logout({String? token}) async {
    try {
      await _apiClient.post('/auth/logout', headers: _buildHeaders(token));
    } finally {
      setAuthToken(null);
    }
  }

  Future<Map<String, dynamic>?> getCurrentSession({String? token}) async {
    final response = await _apiClient.get(
      '/auth/me',
      headers: _buildHeaders(token),
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getUsers({String? token}) async {
    final response = await _apiClient.get(
      '/auth/accounts',
      headers: _buildHeaders(token),
    );
    if (response.success && response.data is List) {
      return (response.data as List)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (!response.success) {
      throw NetworkException(response.message ?? 'تعذر استرجاع الحسابات');
    }
    return const [];
  }

  Future<void> updateUserStatus(
    String userId,
    bool isActive, {
    String? token,
  }) async {
    try {
      final dynamic client = _apiClient;
      final response = await client.patch(
        '/auth/accounts/$userId/toggle-status',
        headers: _buildHeaders(token),
      );
      if (response != null && response.success == false) {
        throw NetworkException(response.message ?? 'فشل تحديث حالة الحساب');
      }
    } catch (e) {
      if (e is NetworkException) rethrow;
      final response = await _apiClient.put(
        '/auth/users/$userId/status',
        body: {
          'is_active': isActive,
          'isActive': isActive,
        },
        headers: _buildHeaders(token),
      );
      if (!response.success) {
        throw NetworkException(response.message ?? 'فشل تحديث حالة الحساب');
      }
    }
  }

  Future<Map<String, dynamic>> createUser(
    Map<String, dynamic> userData, {
    String? token,
  }) async {
    final response = await _apiClient.post(
      '/auth/accounts',
      body: userData,
      headers: _buildHeaders(token),
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw NetworkException(response.message ?? 'فشل إنشاء الحساب في الخادم');
  }

  Future<Map<String, dynamic>> updateUser(
    String userId,
    Map<String, dynamic> userData, {
    String? token,
  }) async {
    final response = await _apiClient.put(
      '/auth/accounts/$userId',
      body: userData,
      headers: _buildHeaders(token),
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw NetworkException(response.message ?? 'فشل تحديث بيانات الحساب');
  }

  Future<Map<String, dynamic>> deleteUser(
    String userId, {
    String? token,
  }) async {
    final response = await _apiClient.delete(
      '/auth/accounts/$userId',
      headers: _buildHeaders(token),
    );
    if (response.success) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'id': userId, 'deleted': true};
    }
    throw NetworkException(response.message ?? 'فشل حذف الحساب من الخادم');
  }

  Future<Map<String, dynamic>> forgotPassword(
    String identifier, {
    String method = 'sms',
  }) async {
    final response = await _apiClient.post(
      '/auth/forgot-password',
      body: {
        'identifier': identifier,
        'method': method,
      },
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw NetworkException(response.message ?? 'فشل طلب استرداد كلمة المرور');
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String otpCode,
    String? otpId,
  }) async {
    final response = await _apiClient.post(
      '/auth/verify-otp',
      body: {
        'identifier': identifier,
        'otpCode': otpCode,
        'otp': otpCode,
        'otp_code': otpCode,
        if (otpId != null) 'otpId': otpId,
      },
    );
    if (response.success && response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    throw NetworkException(response.message ?? 'رمز التحقق غير صحيح أو غير صالح');
  }

  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String resetToken,
    required String newPassword,
    String? confirmPassword,
  }) async {
    final response = await _apiClient.post(
      '/auth/reset-password',
      body: {
        'identifier': identifier,
        'resetToken': resetToken,
        'reset_token': resetToken,
        'newPassword': newPassword,
        'new_password': newPassword,
        if (confirmPassword != null) 'confirmPassword': confirmPassword,
      },
    );
    if (response.success) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'message': response.message ?? 'تمت إعادة تعيين كلمة المرور بنجاح'};
    }
    throw NetworkException(response.message ?? 'تعذر إعادة تعيين كلمة المرور');
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    String? confirmPassword,
    bool logoutOtherDevices = true,
    String? token,
  }) async {
    final response = await _apiClient.post(
      '/auth/change-password',
      body: {
        'currentPassword': currentPassword,
        'current_password': currentPassword,
        'old_password': currentPassword,
        'newPassword': newPassword,
        'new_password': newPassword,
        if (confirmPassword != null) 'confirmPassword': confirmPassword,
        'logoutOtherDevices': logoutOtherDevices,
      },
      headers: _buildHeaders(token),
    );
    if (response.success) {
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
      return {'message': response.message ?? 'تم تغيير كلمة المرور بنجاح'};
    }
    throw NetworkException(response.message ?? 'تعذر تغيير كلمة المرور');
  }

  Future<Map<String, dynamic>?> getCeoMetrics({String? token}) async {
    try {
      final response = await _apiClient.get(
        '/dashboards/ceo',
        headers: _buildHeaders(token),
      );
      if (response.success && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getBranchMetrics(String branchId, {String? token}) async {
    try {
      final response = await _apiClient.get(
        '/dashboards/branch/$branchId',
        headers: _buildHeaders(token),
      );
      if (response.success && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> getSupplyMetrics({String? token}) async {
    try {
      final response = await _apiClient.get(
        '/dashboards/supply',
        headers: _buildHeaders(token),
      );
      if (response.success && response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
