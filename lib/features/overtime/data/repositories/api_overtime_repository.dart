import '../../../../core/network/authenticated_api.dart';
import '../../domain/entities/overtime_record.dart';

class ApiOvertimeRepository {
  ApiOvertimeRepository(this.api);

  final AuthenticatedApi api;

  Future<List<OvertimeRecord>> list({String? status}) async {
    final suffix = status == null ? '' : '?status=$status';
    final data = await api.get('/api/v1/overtime$suffix');
    final records = data is Map ? data['records'] : null;
    if (records is! List) return const [];
    return records.whereType<Map>().map(_fromJson).toList();
  }

  Future<OvertimeRecord> create({
    required String employeeId,
    required String workDate,
    required double hours,
    required double ratePerHour,
    String source = 'manual',
  }) async {
    final data = await api.post('/api/v1/overtime', {
      'employee_id': employeeId,
      'work_date': workDate,
      'hours': hours,
      'rate_per_hour': ratePerHour,
      'source': source,
    });
    return _fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<OvertimeRecord> approve(String id) async {
    final data = await api.patch('/api/v1/overtime/$id/approve', {});
    return _fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<OvertimeRecord> reject(String id, String reason) async {
    final data = await api.patch('/api/v1/overtime/$id/reject', {
      'reason': reason,
    });
    return _fromJson(Map<String, dynamic>.from(data as Map));
  }

  OvertimeRecord _fromJson(Map value) {
    final status = '${value['status'] ?? 'pending'}';
    return OvertimeRecord(
      id: '${value['id'] ?? ''}',
      employeeName: '${value['employee_id'] ?? ''}',
      employeeCode: '${value['employee_id'] ?? ''}',
      role: 'بيانات الموظف من قاعدة البيانات',
      date: '${value['work_date'] ?? ''}',
      hours: (value['hours'] as num?)?.toDouble() ?? 0,
      timeRange: 'غير متاح من واجهة API',
      reason: 'سجل ساعات إضافية فعلي',
      trigger: '${value['source']}' == 'fingerprint'
          ? OvertimeTrigger.fingerprint
          : OvertimeTrigger.managerRequest,
      status: switch (status) {
        'approved' => OvertimeStatus.approved,
        'rejected' => OvertimeStatus.rejected,
        _ => OvertimeStatus.pendingReview,
      },
      overtimePay: (value['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}
