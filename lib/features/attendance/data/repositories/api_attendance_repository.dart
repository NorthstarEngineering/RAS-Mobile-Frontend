import '../../../../core/network/authenticated_api.dart';

class ApiAttendanceRepository {
  ApiAttendanceRepository(this.api);

  final AuthenticatedApi api;

  Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    String source = 'manual',
  }) async {
    final data = await api.post('/api/v1/attendance/check-in', {
      'employee_id': employeeId,
      'source': source,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> checkOut({required String employeeId}) async {
    final data = await api.post('/api/v1/attendance/check-out', {
      'employee_id': employeeId,
    });
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> adjustDeduction({
    required String deductionId,
    double? newAmount,
    required bool cancel,
    required String reason,
  }) async {
    final data = await api.patch('/api/v1/attendance/deductions/$deductionId', {
      if (newAmount != null) 'new_amount': newAmount,
      'cancel': cancel,
      'reason': reason,
    });
    return Map<String, dynamic>.from(data as Map);
  }
}
