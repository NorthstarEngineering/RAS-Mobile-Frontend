import '../entities/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<AttendanceRecord>> getAttendanceRecords({
    String? date,
    String? branchId,
    String? status,
  });

  Future<AttendanceRecord?> getAttendanceById(String id);

  Future<AttendanceRecord> checkIn({
    required String employeeId,
    required String branchId,
    String? date,
    String? checkInTime,
    String? shiftName,
    int? lateMinutes,
  });

  Future<AttendanceRecord> checkOut({
    required String attendanceId,
    String? checkOutTime,
  });

  Future<AttendanceRecord> adjustDeduction({
    required String attendanceId,
    required double deductionAmount,
    required String reason,
    int waivedMinutes = 0,
    String? adjustedByUserId,
    int? originalLateMinutes,
  });

  Future<List<AttendanceRecord>> getEmployeeAttendanceHistory(
    String employeeId, {
    int? month,
    int? year,
  });

  Future<bool> syncBiometricDevices();
}
