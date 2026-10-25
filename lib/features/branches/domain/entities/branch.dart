import 'package:equatable/equatable.dart';

enum BranchType {
  dining('فرع صالة وخدمة مباشرة'),
  kitchen('مطبخ ومستودع مركزي');

  const BranchType(this.titleArabic);
  final String titleArabic;
}

class Branch extends Equatable {
  final String id;
  final String code;
  final String name;
  final String address;
  final String phone;
  final String managerName;
  final int employeeCount;
  final double efficiencyRate;
  final BranchType type;
  final bool isMain;
  final bool isActive;
  final String workingHours;
  final int posTerminalsCount;

  const Branch({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.phone,
    required this.managerName,
    required this.employeeCount,
    required this.efficiencyRate,
    this.type = BranchType.dining,
    this.isMain = false,
    this.isActive = true,
    this.workingHours = '09:00 ص - 01:00 ص',
    this.posTerminalsCount = 4,
  });

  @override
  List<Object?> get props => [
        id,
        code,
        name,
        address,
        phone,
        managerName,
        employeeCount,
        efficiencyRate,
        type,
        isMain,
        isActive,
        workingHours,
        posTerminalsCount,
      ];
}
