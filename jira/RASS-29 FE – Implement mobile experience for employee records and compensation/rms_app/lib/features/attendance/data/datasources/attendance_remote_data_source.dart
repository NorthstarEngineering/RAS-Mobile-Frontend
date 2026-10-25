import '../../../../core/network/api_client.dart';

abstract class AttendanceRemoteDataSource {
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    String? date,
    String? branchId,
    String? status,
  });

  Future<Map<String, dynamic>?> getAttendanceById(String id);

  Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    required String branchId,
    String? date,
    String? checkInTime,
    String? shiftName,
    int? lateMinutes,
  });

  Future<Map<String, dynamic>> checkOut({
    required String attendanceId,
    String? checkOutTime,
  });

  Future<Map<String, dynamic>> adjustDeduction({
    required String attendanceId,
    required double deductionAmount,
    required String reason,
    int waivedMinutes = 0,
    String? adjustedByUserId,
    int? originalLateMinutes,
  });

  Future<List<Map<String, dynamic>>> getEmployeeAttendanceHistory(
    String employeeId, {
    int? month,
    int? year,
  });

  Future<bool> syncBiometricDevices();
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  AttendanceRemoteDataSourceImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  @override
  Future<List<Map<String, dynamic>>> getAttendanceRecords({
    String? date,
    String? branchId,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (date != null) queryParams['date'] = date;
    if (branchId != null) queryParams['branch_id'] = branchId;
    if (status != null) queryParams['status'] = status;

    String path = '/attendance';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$query';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is List) {
      final list = res.data as List;
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>?> getAttendanceById(String id) async {
    final res = await _apiClient.get('/attendance/$id');
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>> checkIn({
    required String employeeId,
    required String branchId,
    String? date,
    String? checkInTime,
    String? shiftName,
    int? lateMinutes,
  }) async {
    final payload = <String, dynamic>{
      'employeeId': employeeId,
      'branchId': branchId,
      if (date != null) 'date': date,
      if (checkInTime != null) 'checkInTime': checkInTime,
      if (shiftName != null) 'shiftName': shiftName,
      if (lateMinutes != null) 'lateMinutes': lateMinutes,
    };
    final res = await _apiClient.post('/attendance/check-in', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تسجيل الحضور');
  }

  @override
  Future<Map<String, dynamic>> checkOut({
    required String attendanceId,
    String? checkOutTime,
  }) async {
    final payload = <String, dynamic>{
      'attendanceId': attendanceId,
      if (checkOutTime != null) 'checkOutTime': checkOutTime,
    };
    final res = await _apiClient.post('/attendance/check-out', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تسجيل الانصراف');
  }

  @override
  Future<Map<String, dynamic>> adjustDeduction({
    required String attendanceId,
    required double deductionAmount,
    required String reason,
    int waivedMinutes = 0,
    String? adjustedByUserId,
    int? originalLateMinutes,
  }) async {
    final payload = <String, dynamic>{
      'attendanceId': attendanceId,
      'deductionAmount': deductionAmount,
      'reason': reason,
      'waivedMinutes': waivedMinutes,
      'adjustedByUserId': adjustedByUserId ?? 'usr_bm1',
      if (originalLateMinutes != null) 'originalLateMinutes': originalLateMinutes,
    };
    final res = await _apiClient.post('/attendance/adjust-deduction', body: payload);
    if (res.success && res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }
    throw Exception(res.error?.toString() ?? 'فشل تسوية الخصم الإداري');
  }

  @override
  Future<List<Map<String, dynamic>>> getEmployeeAttendanceHistory(
    String employeeId, {
    int? month,
    int? year,
  }) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month.toString();
    if (year != null) queryParams['year'] = year.toString();

    String path = '/attendance/history/$employeeId';
    if (queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      path = '$path?$query';
    }

    final res = await _apiClient.get(path);
    if (res.success && res.data is Map) {
      final dataMap = Map<String, dynamic>.from(res.data as Map);
      final records = dataMap['records'];
      if (records is List) {
        return records
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<bool> syncBiometricDevices() async {
    final res = await _apiClient.post('/attendance/sync-devices');
    return res.success;
  }
}
