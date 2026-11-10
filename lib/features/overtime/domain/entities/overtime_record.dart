import 'package:equatable/equatable.dart';

enum OvertimeStatus {
  pendingReview('بانتظار المراجعة'),
  approved('معتمد'),
  rejected('مرفوض');

  const OvertimeStatus(this.titleArabic);
  final String titleArabic;
}

enum OvertimeTrigger {
  fingerprint('بصمة تلقائية'),
  managerRequest('تكليف يدوي');

  const OvertimeTrigger(this.titleArabic);
  final String titleArabic;
}

class OvertimeRecord extends Equatable {
  const OvertimeRecord({
    required this.id,
    required this.employeeName,
    required this.employeeCode,
    required this.role,
    required this.date,
    required this.hours,
    required this.timeRange,
    required this.reason,
    required this.trigger,
    required this.status,
    required this.overtimePay,
  });

  final String id;
  final String employeeName;
  final String employeeCode;
  final String role;
  final String date;
  final double hours;
  final String timeRange;
  final String reason;
  final OvertimeTrigger trigger;
  final OvertimeStatus status;
  final double overtimePay;

  String get initials {
    final parts = employeeName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return employeeName.isNotEmpty ? employeeName[0] : 'م';
  }

  OvertimeRecord copyWith({OvertimeStatus? status}) {
    return OvertimeRecord(
      id: id,
      employeeName: employeeName,
      employeeCode: employeeCode,
      role: role,
      date: date,
      hours: hours,
      timeRange: timeRange,
      reason: reason,
      trigger: trigger,
      status: status ?? this.status,
      overtimePay: overtimePay,
    );
  }

  @override
  List<Object?> get props => [
    id,
    employeeName,
    employeeCode,
    role,
    date,
    hours,
    timeRange,
    reason,
    trigger,
    status,
    overtimePay,
  ];
}
