import 'package:equatable/equatable.dart';

enum WageType {
  monthly('شهري'),
  hourly('بالساعة');

  const WageType(this.titleArabic);
  final String titleArabic;
}

enum EmployeeStatus {
  active('نشط'),
  activeOnShift('نشط (في الوردية)'),
  onLeave('في إجازة'),
  suspended('موقوف مؤقتاً');

  const EmployeeStatus(this.titleArabic);
  final String titleArabic;
}

class Employee extends Equatable {
  const Employee({
    required this.id,
    required this.code,
    required this.name,
    required this.role,
    required this.branchName,
    required this.branchCode,
    required this.status,
    required this.wageType,
    required this.baseSalary,
    required this.overtimeRate,
    required this.phone,
    required this.managerName,
    this.totalHoursThisMonth = 168.0,
    this.department = 'FOH/BOH',
  });

  final String id;
  final String code;
  final String name;
  final String role;
  final String branchName;
  final String branchCode;
  final EmployeeStatus status;
  final WageType wageType;
  final double baseSalary;
  final double overtimeRate;
  final String phone;
  final String managerName;
  final double totalHoursThisMonth;
  final String department;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return name.isNotEmpty ? name[0] : 'م';
  }

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        role,
        branchName,
        branchCode,
        status,
        wageType,
        baseSalary,
        overtimeRate,
        phone,
        managerName,
        totalHoursThisMonth,
        department,
      ];
}
