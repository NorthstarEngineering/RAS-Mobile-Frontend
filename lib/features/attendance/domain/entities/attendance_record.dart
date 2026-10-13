import 'package:equatable/equatable.dart';

enum AttendanceStatus {
  present('منضبط (حاضر)'),
  late('متأخر'),
  absent('غياب غير مبرر');

  const AttendanceStatus(this.titleArabic);
  final String titleArabic;
}

class AttendanceRecord extends Equatable {
  const AttendanceRecord({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.role,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    this.delayMinutes = 0,
    this.deductionAmount = 0.0,
    this.isDeductionAdjusted = false,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String role;
  final String checkInTime;
  final String? checkOutTime;
  final AttendanceStatus status;
  final int delayMinutes;
  final double deductionAmount;
  final bool isDeductionAdjusted;

  String get initials {
    final parts = employeeName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return employeeName.isNotEmpty ? employeeName[0] : 'م';
  }

  AttendanceRecord copyWith({
    double? deductionAmount,
    bool? isDeductionAdjusted,
  }) {
    return AttendanceRecord(
      id: id,
      employeeName: employeeName,
      employeeCode: employeeCode,
      role: role,
      checkInTime: checkInTime,
      checkOutTime: checkOutTime,
      status: status,
      delayMinutes: delayMinutes,
      deductionAmount: deductionAmount ?? this.deductionAmount,
      isDeductionAdjusted: isDeductionAdjusted ?? this.isDeductionAdjusted,
    );
  }

  @override
  List<Object?> get props => [
        id,
        employeeName,
        employeeCode,
        role,
        checkInTime,
        checkOutTime,
        status,
        delayMinutes,
        deductionAmount,
        isDeductionAdjusted,
      ];
}
