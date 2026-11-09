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
import '../../features/branches/presentation/screens/create_branch_screen.dart';
import '../../features/design_system_preview/design_system_preview_screen.dart';
import '../../features/employees/domain/entities/employee.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/employees/presentation/screens/create_employee_screen.dart';
import '../../features/employees/presentation/screens/edit_employee_screen.dart';
import '../../features/employees/presentation/screens/employee_compensation_screen.dart';
import '../../features/employees/presentation/screens/employee_details_screen.dart';
import '../../features/employees/presentation/screens/employee_list_screen.dart';
import '../../features/attendance/domain/entities/attendance_record.dart';
import '../../features/attendance/presentation/screens/attendance_details_screen.dart';
import '../../features/attendance/presentation/screens/attendance_list_screen.dart';
import '../../features/attendance/presentation/screens/deduction_adjustment_screen.dart';
import '../../features/overtime/domain/entities/overtime_record.dart';
import '../../features/overtime/presentation/screens/create_overtime_screen.dart';
import '../../features/overtime/presentation/screens/overtime_list_screen.dart';
import '../../features/overtime/presentation/screens/overtime_review_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  redirect: (context, state) {
    final path = state.uri.path;
    final isPublic =
        path == '/splash' || path == '/login' || path.startsWith('/auth/');
    final isAuthenticated = sl<AuthBloc>().state.isAuthenticated;
    if (!isPublic && !isAuthenticated) return '/login';
    if (path == '/login' && isAuthenticated) return '/home';
    if (path.startsWith('/menu') || path.startsWith('/pricing')) {
      return '/under-development';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/under-development',
      name: 'under-development',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'بيانات التشغيل والخدمات'),
      ),
    ),
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
        final identifier = (state.extra as String?) ?? '';
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
      builder: (context, state) =>
          const MobileViewport(child: ChangePasswordScreen()),
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
      builder: (context, state) => MobileViewport(
        child: BlocProvider.value(
          value: sl<AuthBloc>(),
          child: const ProfileAccountScreen(),
        ),
      ),
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
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'عمليات المطبخ المركزي'),
      ),
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
        final emp = state.extra as Employee?;
        if (emp == null) {
          return const MobileViewport(
            child: UnderDevelopmentScreen(
              feature: 'تعديل موظف بدون بيانات الموظف',
            ),
          );
        }
        return MobileViewport(child: EditEmployeeScreen(employee: emp));
      },
    ),
    GoRoute(
      path: '/employees/:id/compensation',
      name: 'employee-compensation',
      builder: (context, state) {
        final emp = state.extra as Employee?;
        if (emp == null) {
          return const MobileViewport(
            child: UnderDevelopmentScreen(
              feature: 'تعويضات الموظف بدون بيانات الموظف',
            ),
          );
        }
        return MobileViewport(child: EmployeeCompensationScreen(employee: emp));
      },
    ),
    GoRoute(
      path: '/employees/:id/pay-history',
      name: 'employee-pay-history',
      builder: (context, state) {
        return const MobileViewport(
          child: UnderDevelopmentScreen(feature: 'السجل المالي للموظف'),
        );
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
        final record = state.extra as AttendanceRecord?;
        if (record == null) {
          return const MobileViewport(
            child: UnderDevelopmentScreen(
              feature: 'تفاصيل حضور بدون سجل من قاعدة البيانات',
            ),
          );
        }
        return MobileViewport(child: AttendanceDetailsScreen(record: record));
      },
    ),
    GoRoute(
      path: '/attendance/adjust',
      name: 'attendance-adjust',
      builder: (context, state) {
        final record = state.extra as AttendanceRecord?;
        if (record == null) {
          return const MobileViewport(
            child: UnderDevelopmentScreen(
              feature: 'تعديل خصم بدون سجل من قاعدة البيانات',
            ),
          );
        }
        return MobileViewport(child: DeductionAdjustmentScreen(record: record));
      },
    ),
    GoRoute(
      path: '/attendance/history',
      name: 'attendance-history',
      builder: (context, state) {
        return const MobileViewport(
          child: UnderDevelopmentScreen(feature: 'سجل الحضور التاريخي'),
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
        final record = state.extra as OvertimeRecord?;
        if (record == null) {
          return const MobileViewport(
            child: UnderDevelopmentScreen(
              feature: 'مراجعة ساعات إضافية بدون سجل من قاعدة البيانات',
            ),
          );
        }
        return MobileViewport(child: OvertimeReviewScreen(record: record));
      },
    ),
    // Story 6 (MENU) Routes
    GoRoute(
      path: '/menu',
      name: 'master-menu',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'إدارة قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/categories',
      name: 'menu-categories',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'تصنيفات قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/create',
      name: 'create-menu-item',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'إنشاء عنصر قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/edit/:id',
      name: 'edit-menu-item',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'تعديل عنصر قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/requests',
      name: 'menu-requests',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'طلبات قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/requests/:id',
      name: 'menu-request-review',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'مراجعة طلب قائمة الطعام'),
      ),
    ),
    GoRoute(
      path: '/menu/:id',
      name: 'menu-item-details',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'تفاصيل عنصر قائمة الطعام'),
      ),
    ),
    // Story 7 (PRICE) Routes
    GoRoute(
      path: '/pricing/requests',
      name: 'price-requests',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'طلبات تغيير الأسعار'),
      ),
    ),
    GoRoute(
      path: '/pricing/requests/:id',
      name: 'price-review',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'مراجعة تغيير الأسعار'),
      ),
    ),
    GoRoute(
      path: '/pricing/history/:id',
      name: 'price-history',
      builder: (context, state) => const MobileViewport(
        child: UnderDevelopmentScreen(feature: 'سجل الأسعار'),
      ),
    ),
    GoRoute(
      path: '/preview',
      name: 'preview',
      builder: (context, state) =>
          const MobileViewport(child: DesignSystemPreviewScreen()),
    ),
  ],
);
