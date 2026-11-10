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
    this.branchId = '',
    this.branchName = '',
  });

  final String id;
  final String name;
  final String email;
  final StaffRole role;
  final String token;
  final String refreshToken;
  final String branchId;
  final String branchName;

  Map<String, String> toStorage() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.code,
    'token': token,
    'refreshToken': refreshToken,
    'branchId': branchId,
    'branchName': branchName,
  };

  factory UserSession.fromStorage(Map<String, String> values) => UserSession(
    id: values['id'] ?? '',
    name: values['name'] ?? '',
    email: values['email'] ?? '',
    role: StaffRole.values.firstWhere(
      (role) => role.code == values['role'],
      orElse: () => StaffRole.ceo,
    ),
    token: values['token'] ?? '',
    refreshToken: values['refreshToken'] ?? '',
    branchId: values['branchId'] ?? '',
    branchName: values['branchName'] ?? '',
  );

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    role,
    token,
    refreshToken,
    branchId,
    branchName,
  ];
}
