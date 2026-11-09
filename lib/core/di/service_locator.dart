import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/authenticated_api.dart';
import '../../features/auth/data/repositories/api_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/branches/data/repositories/api_branch_repository.dart';
import '../../features/branches/domain/repositories/branch_repository.dart';
import '../../features/attendance/data/repositories/api_attendance_repository.dart';
import '../../features/employees/data/repositories/api_employee_repository.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/overtime/data/repositories/api_overtime_repository.dart';
import '../../features/menu/data/repositories/mock_menu_repository.dart';
import '../../features/menu/domain/repositories/menu_repository.dart';
import '../../features/pricing/data/repositories/mock_pricing_repository.dart';
import '../../features/pricing/domain/repositories/pricing_repository.dart';

final sl = GetIt.instance;
final getIt = sl;

Future<void> initServiceLocator() async {
  final preferences = await SharedPreferences.getInstance();
  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => ApiAuthRepository(preferences: preferences),
  );
  sl.registerLazySingleton(() {
    final auth = sl<AuthRepository>();
    if (auth is! ApiAuthRepository) {
      throw StateError('API authentication is required for live repositories');
    }
    return AuthenticatedApi(auth);
  });
  sl.registerLazySingleton<BranchRepository>(
    () => ApiBranchRepository(sl<AuthenticatedApi>()),
  );
  sl.registerLazySingleton<EmployeeRepository>(
    () => ApiEmployeeRepository(sl<AuthenticatedApi>()),
  );
  sl.registerLazySingleton(
    () => ApiAttendanceRepository(sl<AuthenticatedApi>()),
  );
  sl.registerLazySingleton(() => ApiOvertimeRepository(sl<AuthenticatedApi>()));
  sl.registerLazySingleton<MenuRepository>(() => MockMenuRepository());
  sl.registerLazySingleton<PricingRepository>(() => MockPricingRepository());

  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  // BLoCs
  sl.registerLazySingleton(() => AuthBloc(loginUseCase: sl()));
}
