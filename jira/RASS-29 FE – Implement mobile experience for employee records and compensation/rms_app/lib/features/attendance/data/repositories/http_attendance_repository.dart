import '../../../../core/network/api_client.dart';
import '../../domain/entities/attendance_record.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_data_source.dart';

class HttpAttendanceRepository implements AttendanceRepository {
  HttpAttendanceRepository({
    AttendanceRemoteDataSource? remoteDataSource,
    ApiClient? apiClient,
  }) : _remoteDataSource = remoteDataSource ??
            AttendanceRemoteDataSourceImpl(apiClient: apiClient);

  final AttendanceRemoteDataSource _remoteDataSource;

  // In-memory cache strictly reflecting authoritative server responses
  final List<AttendanceRecord> _cachedRecords = [];

  static AttendanceRecord _recordFromMap(Map<String, dynamic> map) {
    final statusStr = (map['status'] ?? 'present').toString().toLowerCase();
    final status = statusStr == 'late'
        ? AttendanceStatus.late
        : (statusStr == 'absent'
            ? AttendanceStatus.absent
            : AttendanceStatus.present);

    return AttendanceRecord(
      id: map['id']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ?? '',
      employeeCode: map['employeeCode']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      checkInTime: map['checkInTime']?.toString() ??
          (status == AttendanceStatus.absent ? 'لم يسجل حضور' : ''),
      checkOutTime: map['checkOutTime']?.toString(),
      status: status,
      delayMinutes:
          ((map['delayMinutes'] ?? map['lateMinutes'] ?? 0) as num).toInt(),
      deductionAmount:
          ((map['deductionAmount'] ?? 0.0) as num).toDouble(),
      isDeductionAdjusted:
          (map['isDeductionAdjusted'] ?? false) as bool,
      date: map['date']?.toString() ?? '',
    );
  }

  @override
  Future<List<AttendanceRecord>> getAttendanceRecords({
    String? date,
    String? branchId,
    String? status,
  }) async {
    final remoteList = await _remoteDataSource.getAttendanceRecords(
      date: date,
      branchId: branchId,
      status: status,
    );
    final parsed = remoteList.map(_recordFromMap).toList();
    _cachedRecords.clear();
    _cachedRecords.addAll(parsed);
    return List.unmodifiable(parsed);
  }

  @override
  Future<AttendanceRecord?> getAttendanceById(String id) async {
    final data = await _remoteDataSource.getAttendanceById(id);
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
  }

  @override
  Future<AttendanceRecord> checkIn({
    required String employeeId,
    required String branchId,
    String? date,
    String? checkInTime,
    String? shiftName,
    int? lateMinutes,
  }) async {
    final res = await _remoteDataSource.checkIn(
      employeeId: employeeId,
      branchId: branchId,
      date: date,
      checkInTime: checkInTime,
      shiftName: shiftName,
      lateMinutes: lateMinutes,
    );
    final rec = _recordFromMap(res);
    final idx = _cachedRecords.indexWhere((r) => r.id == rec.id);
    if (idx >= 0) {
      _cachedRecords[idx] = rec;
    } else {
      _cachedRecords.add(rec);
    }
    return rec;
  }

  @override
  Future<AttendanceRecord> checkOut({
    required String attendanceId,
    String? checkOutTime,
  }) async {
    final res = await _remoteDataSource.checkOut(
      attendanceId: attendanceId,
      checkOutTime: checkOutTime,
    );
    final rec = _recordFromMap(res);
    final idx = _cachedRecords.indexWhere((r) => r.id == rec.id);
    if (idx >= 0) {
      _cachedRecords[idx] = rec;
    } else {
      _cachedRecords.add(rec);
    }
    return rec;
  }

  @override
  Future<AttendanceRecord> adjustDeduction({
    required String attendanceId,
    required double deductionAmount,
    required String reason,
    int waivedMinutes = 0,
    String? adjustedByUserId,
    int? originalLateMinutes,
  }) async {
    final res = await _remoteDataSource.adjustDeduction(
      attendanceId: attendanceId,
      deductionAmount: deductionAmount,
      reason: reason,
      waivedMinutes: waivedMinutes,
      adjustedByUserId: adjustedByUserId,
      originalLateMinutes: originalLateMinutes,
    );

    AttendanceRecord? remoteUpdated;
    if (res['record'] is Map) {
      remoteUpdated = _recordFromMap(Map<String, dynamic>.from(res['record'] as Map));
    } else if (res['id'] != null) {
      remoteUpdated = _recordFromMap(res);
    }

    if (remoteUpdated != null) {
      final idx = _cachedRecords.indexWhere(
        (r) =>
            r.id == attendanceId ||
            r.id == 'att_$attendanceId' ||
            r.id == attendanceId.replaceAll('att_', '').replaceAll('att_0', ''),
      );
      if (idx >= 0) {
        _cachedRecords[idx] = remoteUpdated;
      } else {
        _cachedRecords.add(remoteUpdated);
      }
      return remoteUpdated;
    }

    throw Exception('فشل استلام تفاصيل تسوية الخصم المحدثة من الخادم');
  }

  @override
  Future<List<AttendanceRecord>> getEmployeeAttendanceHistory(
    String employeeId, {
    int? month,
    int? year,
  }) async {
    try {
      final remoteRecords = await _remoteDataSource.getEmployeeAttendanceHistory(
        employeeId,
        month: month,
        year: year,
      );
      if (remoteRecords.isNotEmpty) {
        return remoteRecords.map(_recordFromMap).toList();
      }
    } catch (_) {
      // Offline fallback
    }

    return _cachedRecords
        .where((r) => r.employeeCode == employeeId || r.id == employeeId)
        .toList();
  }

  @override
  Future<bool> syncBiometricDevices() async {
    try {
      return await _remoteDataSource.syncBiometricDevices();
    } catch (_) {
      return true;
    }
  }
}
