import 'api_services.dart';

/// Source-backed operations. Mutations are deliberately never retried by the
/// HTTP layer because these routes do not accept idempotency keys.
class RasApi {
  RasApi(this._services);
  final ApiServices _services;

  Future<Map<String, dynamic>> checkIn(String employeeId) async => _object(
    await _services.attendance.post('/attendance/check-in', {
      'employee_id': employeeId,
      'source': 'manual',
    }),
  );
  Future<Map<String, dynamic>> checkOut(String employeeId) async => _object(
    await _services.attendance.post('/attendance/check-out', {
      'employee_id': employeeId,
    }),
  );
  Future<Map<String, dynamic>> adjustDeduction(
    String id, {
    double? newAmount,
    bool cancel = false,
    required String reason,
  }) async => _object(
    await _services.attendance.patch('/attendance/deductions/$id', {
      if (newAmount != null) 'new_amount': newAmount,
      'cancel': cancel,
      'reason': reason,
    }),
  );

  Future<Map<String, dynamic>> createOvertime({
    required String employeeId,
    required String workDate,
    required double hours,
    required double ratePerHour,
  }) async => _object(
    await _services.attendance.post('/overtime', {
      'employee_id': employeeId,
      'work_date': workDate,
      'hours': hours,
      'rate_per_hour': ratePerHour,
      'source': 'manual',
    }),
  );
  Future<Map<String, dynamic>> listOvertime() async =>
      _object(await _services.attendance.get('/overtime'));
  Future<Map<String, dynamic>> approveOvertime(String id) async =>
      _object(await _services.attendance.patch('/overtime/$id/approve'));
  Future<Map<String, dynamic>> rejectOvertime(String id, String reason) async =>
      _object(
        await _services.attendance.patch('/overtime/$id/reject', {
          'reason': reason,
        }),
      );

  Future<Map<String, dynamic>> listUsers() async =>
      _object(await _services.auth.get('/users'));
  Future<Map<String, dynamic>> currentUser() async =>
      _object(await _services.auth.get('/auth/me'));
  Future<Map<String, dynamic>> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async =>
      _object(await _services.auth.patch('/auth/me/email', {
        'new_email': newEmail,
        'current_password': currentPassword,
      }));
  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async =>
      _object(await _services.auth.post('/users', payload));
  Future<Map<String, dynamic>> createBranch(Map<String, dynamic> payload) async =>
      _object(await _services.branches.post('/branches', payload));
  Future<Map<String, dynamic>> updateBranch(
          String id, Map<String, dynamic> payload) async =>
      _object(await _services.branches.patch('/branches/$id', payload));
  Future<Map<String, dynamic>> createEmployee(
          Map<String, dynamic> payload) async =>
      _object(await _services.attendance.post('/employees', payload));
  Future<Map<String, dynamic>> changeEmployeePayment(
          String id, Map<String, dynamic> payload) async =>
      _object(await _services.attendance.patch('/employees/$id/payment', payload));
  Future<void> terminateEmployee(String id, String terminationDate) async =>
      await _services.attendance.post('/employees/$id/terminate', {
        'termination_date': terminationDate,
      });
  Future<void> setUserStatus(String id, bool active) async =>
      await _services.auth.patch('/users/$id/status', {'is_active': active});
  Future<void> resetUserPassword(String id, String password) async =>
      await _services.auth.post('/users/$id/reset-password', {
        'new_password': password,
      });
  Future<void> unlockUser(String id) async =>
      await _services.auth.post('/users/$id/unlock');

  static Map<String, dynamic> _object(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    throw const FormatException('Invalid API response');
  }
}
