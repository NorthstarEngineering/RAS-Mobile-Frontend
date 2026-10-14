import 'package:equatable/equatable.dart';

enum StaffRole {
  shiftLead('مسؤول وردية', 'shift_lead'),
  branchManager('مدير فرع', 'branch_manager'),
  ceo('المدير التنفيذي', 'ceo'),
  cashier('أمين صندوق', 'cashier');

  const StaffRole(this.titleArabic, this.code);
  final String titleArabic;
  final String code;
}

class UserSession extends Equatable {
  const UserSession({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    this.refreshToken = '',
    this.expiresAt,
    this.mustChangePassword = false,
    this.branchId = '104',
    this.branchName = 'الفرع الرئيسي - وسط البلد',
  });

  final String id;
  final String name;
  final String email;
  final StaffRole role;
  final String token;
  final String refreshToken;
  final DateTime? expiresAt;
  final bool mustChangePassword;
  final String branchId;
  final String branchName;

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    role,
    token,
    refreshToken,
    expiresAt,
    mustChangePassword,
    branchId,
    branchName,
  ];
}
