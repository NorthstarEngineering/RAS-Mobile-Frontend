import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/service_locator.dart';
import '../widgets/widgets.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/access_denied_screen.dart';
import '../../features/auth/presentation/screens/ceo_account_management_screen.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/password_reset_success_screen.dart';
import '../../features/auth/presentation/screens/profile_account_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/role_based_home_screen.dart';
import '../../features/auth/presentation/screens/session_expired_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/branches/domain/entities/branch.dart';
import '../../features/branches/presentation/screens/branch_details_screen.dart';
import '../../features/branches/presentation/screens/branch_list_screen.dart';
import '../../features/branches/presentation/screens/central_kitchen_screen.dart';
import '../../features/branches/presentation/screens/create_branch_screen.dart';
import '../../features/design_system_preview/design_system_preview_screen.dart';
import '../../features/employees/domain/entities/employee.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/presentation/screens/create_employee_screen.dart';
import '../../features/employees/presentation/screens/edit_employee_screen.dart';
import '../../features/employees/presentation/screens/employee_compensation_screen.dart';
import '../../features/employees/presentation/screens/employee_details_screen.dart';
import '../../features/employees/presentation/screens/employee_list_screen.dart';
import '../../features/employees/presentation/screens/employee_pay_history_screen.dart';
import '../../features/attendance/domain/entities/attendance_record.dart';
import '../../features/attendance/presentation/screens/attendance_details_screen.dart';
import '../../features/attendance/presentation/screens/attendance_list_screen.dart';
import '../../features/attendance/presentation/screens/deduction_adjustment_screen.dart';
import '../../features/attendance/presentation/screens/employee_attendance_history_screen.dart';
import '../../features/overtime/domain/entities/overtime_record.dart';
import '../../features/overtime/presentation/screens/create_overtime_screen.dart';
import '../../features/overtime/presentation/screens/overtime_list_screen.dart';
import '../../features/overtime/presentation/screens/overtime_review_screen.dart';
import '../../features/menu/presentation/screens/create_edit_menu_item_screen.dart';
import '../../features/menu/presentation/screens/master_menu_screen.dart';
import '../../features/menu/presentation/screens/menu_categories_screen.dart';
import '../../features/menu/presentation/screens/menu_item_details_screen.dart';
import '../../features/menu/presentation/screens/menu_item_request_review_screen.dart';
import '../../features/menu/presentation/screens/menu_item_requests_screen.dart';
import '../../features/pricing/presentation/screens/price_change_requests_screen.dart';
import '../../features/pricing/presentation/screens/price_change_review_screen.dart';
import '../../features/pricing/presentation/screens/price_history_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const MobileViewport(child: SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => MobileViewport(
        child: BlocProvider.value(
          value: sl<AuthBloc>(),
          child: const LoginScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      name: 'forgot-password',
      builder: (context, state) =>
          const MobileViewport(child: ForgotPasswordScreen()),
    ),
    GoRoute(
      path: '/auth/otp',
      name: 'otp',
      builder: (context, state) {
        final identifier = (state.extra as String?) ?? 'm.alvarez@rms-ops.com';
        return MobileViewport(
          child: OtpVerificationScreen(identifier: identifier),
        );
      },
    ),
    GoRoute(
      path: '/auth/reset-password',
      name: 'reset-password',
      builder: (context, state) =>
          const MobileViewport(child: ResetPasswordScreen()),
    ),
    GoRoute(
      path: '/auth/success',
      name: 'success',
      builder: (context, state) =>
          const MobileViewport(child: PasswordResetSuccessScreen()),
    ),
    GoRoute(
      path: '/auth/change-password',
      name: 'change-password',
      builder: (context, state) => MobileViewport(
        child: ChangePasswordScreen(
          requiredForSession: state.uri.queryParameters['required'] == '1',
        ),
      ),
    ),
    GoRoute(
      path: '/auth/session-expired',
      name: 'session-expired',
      builder: (context, state) =>
          const MobileViewport(child: SessionExpiredScreen()),
    ),
    GoRoute(
      path: '/auth/access-denied',
      name: 'access-denied',
      builder: (context, state) =>
          const MobileViewport(child: AccessDeniedScreen()),
    ),
    GoRoute(
      path: '/auth/ceo/accounts',
      name: 'ceo-accounts',
      builder: (context, state) =>
          const MobileViewport(child: CeoAccountManagementScreen()),
    ),
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => MobileViewport(
        child: BlocProvider.value(
          value: sl<AuthBloc>(),
          child: const RoleBasedHomeScreen(),
        ),
      ),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) =>
          const MobileViewport(child: ProfileAccountScreen()),
    ),
    // Branches Routes
    GoRoute(
      path: '/branches',
      name: 'branches',
      builder: (context, state) =>
          const MobileViewport(child: BranchListScreen()),
    ),
    GoRoute(
      path: '/branches/create',
      name: 'create-branch',
      builder: (context, state) =>
          const MobileViewport(child: CreateBranchScreen()),
    ),
    GoRoute(
      path: '/branches/central-kitchen',
      name: 'central-kitchen',
      builder: (context, state) =>
          const MobileViewport(child: CentralKitchenDetailsScreen()),
    ),
    GoRoute(
      path: '/branches/:id',
      name: 'branch-details',
      builder: (context, state) {
        final branch = state.extra as Branch?;
        return MobileViewport(child: BranchDetailsScreen(branch: branch));
      },
    ),
    // Story 3 (EMP) Routes
    GoRoute(
      path: '/employees',
      name: 'employees',
      builder: (context, state) =>
          const MobileViewport(child: EmployeeListScreen()),
    ),
    GoRoute(
      path: '/employees/create',
      name: 'create-employee',
      builder: (context, state) =>
          const MobileViewport(child: CreateEmployeeScreen()),
    ),
    GoRoute(
      path: '/employees/:id',
      name: 'employee-details',
      builder: (context, state) {
        final extraEmp = state.extra as Employee?;
        if (extraEmp != null) {
          return MobileViewport(
            child: EmployeeDetailsScreen(employee: extraEmp),
          );
        }
        final empId = state.pathParameters['id'] ?? '1';
        return FutureBuilder<Employee?>(
          future: sl<EmployeeRepository>().getEmployeeById(empId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.data == null) {
              return const Scaffold(
                body: Center(child: Text('الموظف غير موجود')),
              );
            }
            return MobileViewport(
              child: EmployeeDetailsScreen(employee: snapshot.data!),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/employees/:id/edit',
      name: 'edit-employee',
      builder: (context, state) {
        final emp =
            (state.extra as Employee?) ??
            const Employee(
              id: '1',
              code: 'EMP-042',
              name: 'أحمد محمود رضوان',
              role: 'شيف دي بارتي',
              branchName: 'فرع وسط البلد',
              branchCode: 'CAI-01',
              status: EmployeeStatus.active,
              wageType: WageType.monthly,
              baseSalary: 7500.0,
              overtimeRate: 45.0,
              phone: '01012345678',
              managerName: 'م. ألفاريز',
            );
        return MobileViewport(child: EditEmployeeScreen(employee: emp));
      },
    ),
    GoRoute(
      path: '/employees/:id/compensation',
      name: 'employee-compensation',
      builder: (context, state) {
        final emp =
            (state.extra as Employee?) ??
            const Employee(
              id: '1',
              code: 'EMP-042',
              name: 'أحمد محمود رضوان',
              role: 'شيف دي بارتي',
              branchName: 'فرع وسط البلد',
              branchCode: 'CAI-01',
              status: EmployeeStatus.active,
              wageType: WageType.monthly,
              baseSalary: 7500.0,
              overtimeRate: 45.0,
              phone: '01012345678',
              managerName: 'م. ألفاريز',
            );
        return MobileViewport(child: EmployeeCompensationScreen(employee: emp));
      },
    ),
    GoRoute(
      path: '/employees/:id/pay-history',
      name: 'employee-pay-history',
      builder: (context, state) {
        final emp =
            (state.extra as Employee?) ??
            const Employee(
              id: '1',
              code: 'EMP-042',
              name: 'أحمد محمود رضوان',
              role: 'شيف دي بارتي',
              branchName: 'فرع وسط البلد',
              branchCode: 'CAI-01',
              status: EmployeeStatus.active,
              wageType: WageType.monthly,
              baseSalary: 7500.0,
              overtimeRate: 45.0,
              phone: '01012345678',
              managerName: 'م. ألفاريز',
            );
        return MobileViewport(child: EmployeePayHistoryScreen(employee: emp));
      },
    ),
    // Story 4 (ATT) Routes
    GoRoute(
      path: '/attendance',
      name: 'attendance',
      builder: (context, state) =>
          const MobileViewport(child: AttendanceListScreen()),
    ),
    GoRoute(
      path: '/attendance/details',
      name: 'attendance-details',
      builder: (context, state) {
        final record =
            (state.extra as AttendanceRecord?) ??
            const AttendanceRecord(
              id: 'att_1',
              employeeName: 'أحمد محمود',
              employeeCode: 'EMP-042',
              role: 'شيف دي بارتي',
              checkInTime: '08:35 ص',
              status: AttendanceStatus.late,
              delayMinutes: 35,
              deductionAmount: 75.0,
            );
        return MobileViewport(child: AttendanceDetailsScreen(record: record));
      },
    ),
    GoRoute(
      path: '/attendance/adjust',
      name: 'attendance-adjust',
      builder: (context, state) {
        final record =
            (state.extra as AttendanceRecord?) ??
            const AttendanceRecord(
              id: 'att_1',
              employeeName: 'أحمد محمود',
              employeeCode: 'EMP-042',
              role: 'شيف دي بارتي',
              checkInTime: '08:35 ص',
              status: AttendanceStatus.late,
              delayMinutes: 35,
              deductionAmount: 75.0,
            );
        return MobileViewport(child: DeductionAdjustmentScreen(record: record));
      },
    ),
    GoRoute(
      path: '/attendance/history',
      name: 'attendance-history',
      builder: (context, state) {
        final name = state.extra as String?;
        return MobileViewport(
          child: EmployeeAttendanceHistoryScreen(employeeName: name),
        );
      },
    ),
    // Story 5 (OT) Routes
    GoRoute(
      path: '/overtime',
      name: 'overtime',
      builder: (context, state) =>
          const MobileViewport(child: OvertimeListScreen()),
    ),
    GoRoute(
      path: '/overtime/create',
      name: 'create-overtime',
      builder: (context, state) =>
          const MobileViewport(child: CreateOvertimeScreen()),
    ),
    GoRoute(
      path: '/overtime/review',
      name: 'overtime-review',
      builder: (context, state) {
        final record =
            (state.extra as OvertimeRecord?) ??
            const OvertimeRecord(
              id: 'ot_1',
              employeeName: 'كريم عبد العزيز',
              employeeCode: 'EMP-088',
              role: 'كابتن صالة',
              date: '2024-04-16',
              hours: 2.5,
              timeRange: '05:00 م - 07:30 م',
              reason: 'تغطية ذروة العشاء وزيادة الحجوزات المفاجئة',
              trigger: OvertimeTrigger.managerRequest,
              status: OvertimeStatus.pendingReview,
              overtimePay: 112.5,
            );
        return MobileViewport(child: OvertimeReviewScreen(record: record));
      },
    ),
    // Story 6 (MENU) Routes
    GoRoute(
      path: '/menu',
      name: 'master-menu',
      builder: (context, state) =>
          const MobileViewport(child: MasterMenuScreen()),
    ),
    GoRoute(
      path: '/menu/categories',
      name: 'menu-categories',
      builder: (context, state) =>
          const MobileViewport(child: MenuCategoriesScreen()),
    ),
    GoRoute(
      path: '/menu/create',
      name: 'create-menu-item',
      builder: (context, state) =>
          const MobileViewport(child: CreateEditMenuItemScreen()),
    ),
    GoRoute(
      path: '/menu/edit/:id',
      name: 'edit-menu-item',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        return MobileViewport(child: CreateEditMenuItemScreen(itemId: id));
      },
    ),
    GoRoute(
      path: '/menu/requests',
      name: 'menu-requests',
      builder: (context, state) =>
          const MobileViewport(child: MenuItemRequestsScreen()),
    ),
    GoRoute(
      path: '/menu/requests/:id',
      name: 'menu-request-review',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'req_1';
        return MobileViewport(
          child: MenuItemRequestReviewScreen(requestId: id),
        );
      },
    ),
    GoRoute(
      path: '/menu/:id',
      name: 'menu-item-details',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'item_1';
        return MobileViewport(child: MenuItemDetailsScreen(itemId: id));
      },
    ),
    // Story 7 (PRICE) Routes
    GoRoute(
      path: '/pricing/requests',
      name: 'price-requests',
      builder: (context, state) =>
          const MobileViewport(child: PriceChangeRequestsScreen()),
    ),
    GoRoute(
      path: '/pricing/requests/:id',
      name: 'price-review',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'pcr_1';
        return MobileViewport(child: PriceChangeReviewScreen(requestId: id));
      },
    ),
    GoRoute(
      path: '/pricing/history/:id',
      name: 'price-history',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? 'item_1';
        return MobileViewport(child: PriceHistoryScreen(itemId: id));
      },
    ),
    GoRoute(
      path: '/preview',
      name: 'preview',
      builder: (context, state) =>
          const MobileViewport(child: DesignSystemPreviewScreen()),
    ),
  ],
);
