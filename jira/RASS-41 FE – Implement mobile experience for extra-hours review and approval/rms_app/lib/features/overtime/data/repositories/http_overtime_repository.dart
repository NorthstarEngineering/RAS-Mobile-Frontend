import 'package:http/http.dart' as http;

import '../../../../core/network/api_client.dart';
import '../../domain/entities/overtime_record.dart';
import '../../domain/repositories/overtime_repository.dart';
import '../datasources/overtime_remote_data_source.dart';

/// التنفيذ الفعلي لمستودع الساعات الإضافية المتصل بالخادم الموحد
/// مع ذاكرة تخزين محلية احتياطية (Fallback Cache) لضمان العمل المستمر حتى دون اتصال
class HttpOvertimeRepository implements OvertimeRepository {
  HttpOvertimeRepository({
    OvertimeRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
    http.Client? httpClient,
  }) : _remoteDataSource = remoteDataSource ??
            OvertimeRemoteDataSourceImpl(
              apiClient: apiClient,
              httpClient: httpClient,
            );

  final OvertimeRemoteDataSource _remoteDataSource;

  // ذاكرة تخزين مؤقتة للبيانات الحقيقية المسترجعة من الخادم
  final List<OvertimeRecord> _cachedRecords = [];

  static OvertimeRecord _recordFromMap(Map<String, dynamic> map) {
    final statusRaw = (map['status'] ?? 'pending_review').toString().toLowerCase();
    final OvertimeStatus status;
    if (statusRaw == 'approved' || statusRaw == 'معتمد') {
      status = OvertimeStatus.approved;
    } else if (statusRaw == 'rejected' || statusRaw == 'مرفوض') {
      status = OvertimeStatus.rejected;
    } else {
      status = OvertimeStatus.pendingReview;
    }

    final reason = map['reason']?.toString() ?? '';
    final triggerRaw = map['trigger']?.toString().toLowerCase() ?? '';
    final OvertimeTrigger trigger = (triggerRaw == 'fingerprint' || reason.contains('بصمة'))
        ? OvertimeTrigger.fingerprint
        : OvertimeTrigger.managerRequest;

    final hours = ((map['hours'] ?? 0.0) as num).toDouble();
    final overtimePay = ((map['overtimePay'] ??
            map['calculatedAmount'] ??
            map['calculated_amount'] ??
            0.0) as num)
        .toDouble();

    final rateMultiplier = ((map['rateMultiplier'] ??
            map['rate_multiplier'] ??
            1.5) as num)
        .toDouble();

    return OvertimeRecord(
      id: map['id']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ??
          map['employee_name']?.toString() ??
          'موظف',
      employeeCode: map['employeeCode']?.toString() ??
          map['national_id']?.toString() ??
          map['employee_id']?.toString() ??
          '',
      role: map['role']?.toString() ?? map['job_title']?.toString() ?? 'طاهي خط ساخن',
      date: map['date']?.toString() ?? 'اليوم',
      hours: hours,
      timeRange: map['timeRange']?.toString() ??
          map['time_range']?.toString() ??
          'عمل إضافي ${hours.toStringAsFixed(1)} ساعة',
      reason: reason,
      trigger: trigger,
      status: status,
      overtimePay: overtimePay,
      employeeId: map['employeeId']?.toString() ?? map['employee_id']?.toString(),
      branchId: map['branchId']?.toString() ?? map['branch_id']?.toString(),
      branchName: map['branchName']?.toString() ?? map['branch_name']?.toString(),
      rateMultiplier: rateMultiplier,
      decisionReason: map['decisionReason']?.toString() ?? map['decision_reason']?.toString(),
      approvedByName: map['approvedByName']?.toString() ?? map['approver_name']?.toString(),
    );
  }

  @override
  Future<List<OvertimeRecord>> getOvertimeRecords({
    OvertimeStatus? status,
    String? employeeId,
    String? branchId,
  }) async {
    try {
      final statusStr = status != null
          ? (status == OvertimeStatus.pendingReview
              ? 'pending_review'
              : status.name)
          : null;

      final remoteList = await _remoteDataSource.getOvertimeRecords(
        status: statusStr,
        employeeId: employeeId,
        branchId: branchId,
      );

      final parsed = remoteList.map(_recordFromMap).toList();
      _cachedRecords.clear();
      _cachedRecords.addAll(parsed);
      return List.unmodifiable(parsed);
    } catch (e) {
      if (_cachedRecords.isNotEmpty) {
        var result = List<OvertimeRecord>.from(_cachedRecords);
        if (status != null) {
          result = result.where((r) => r.status == status).toList();
        }
        return List.unmodifiable(result);
      }
      rethrow;
    }
  }

  @override
  Future<OvertimeRecord?> getOvertimeRecordById(String id) async {
    try {
      final data = await _remoteDataSource.getOvertimeRecordById(id);
      if (data != null) {
        final rec = _recordFromMap(data);
        final idx = _cachedRecords.indexWhere((r) => r.id == id);
        if (idx >= 0) {
          _cachedRecords[idx] = rec;
        } else {
          _cachedRecords.add(rec);
        }
        return rec;
      }
      return null;
    } catch (e) {
      final cached = _cachedRecords.where((r) => r.id == id);
      if (cached.isNotEmpty) return cached.first;
      rethrow;
    }
  }

  @override
  Future<OvertimeRecord> createOvertimeRecord({
    required String employeeId,
    required double hours,
    required String reason,
    String? id,
    String? branchId,
    String? date,
    double rateMultiplier = 1.5,
    double? hourlyRate,
    double? calculatedAmount,
    String? timeRange,
    OvertimeTrigger trigger = OvertimeTrigger.managerRequest,
    String? employeeName,
    String? role,
  }) async {
    final triggerStr = trigger == OvertimeTrigger.fingerprint ? 'fingerprint' : 'managerRequest';
    final data = await _remoteDataSource.createOvertimeRecord(
      employeeId: employeeId,
      hours: hours,
      reason: reason,
      id: id,
      branchId: branchId,
      date: date,
      rateMultiplier: rateMultiplier,
      hourlyRate: hourlyRate,
      calculatedAmount: calculatedAmount,
      timeRange: timeRange,
      trigger: triggerStr,
    );
    final rec = _recordFromMap(data);
    _cachedRecords.insert(0, rec);
    return rec;
  }

  @override
  Future<OvertimeRecord> reviewOvertimeRecord({
    required String id,
    String? reviewerId,
    String? notes,
    double? hours,
    double? rateMultiplier,
  }) async {
    final data = await _remoteDataSource.reviewOvertimeRecord(
      id: id,
      reviewerId: reviewerId,
      notes: notes,
      hours: hours,
      rateMultiplier: rateMultiplier,
    );
    final rec = _recordFromMap(data);
    final idx = _cachedRecords.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _cachedRecords[idx] = rec;
    } else {
      _cachedRecords.add(rec);
    }
    return rec;
  }

  @override
  Future<OvertimeRecord> approveOvertimeRecord({
    required String id,
    required bool isApproved,
    String? approvedByUserId,
    String? decisionReason,
  }) async {
    final data = await _remoteDataSource.approveOvertimeRecord(
      id: id,
      isApproved: isApproved,
      approvedByUserId: approvedByUserId,
      decisionReason: decisionReason,
    );
    final rec = _recordFromMap(data);
    final idx = _cachedRecords.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _cachedRecords[idx] = rec;
    } else {
      _cachedRecords.add(rec);
    }
    return rec;
  }
}
