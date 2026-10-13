import 'package:get_it/get_it.dart';

import '../../features/auth/data/repositories/mock_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/employees/data/repositories/mock_employee_repository.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/menu/data/repositories/mock_menu_repository.dart';
import '../../features/menu/domain/repositories/menu_repository.dart';
import '../../features/pricing/data/repositories/mock_pricing_repository.dart';
import '../../features/pricing/domain/repositories/pricing_repository.dart';

final sl = GetIt.instance;
final getIt = sl;

Future<void> initServiceLocator() async {
  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => MockAuthRepository());
  sl.registerLazySingleton<EmployeeRepository>(() => MockEmployeeRepository());
  sl.registerLazySingleton<MenuRepository>(() => MockMenuRepository());
  sl.registerLazySingleton<PricingRepository>(() => MockPricingRepository());

  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  // BLoCs
  sl.registerLazySingleton(() => AuthBloc(loginUseCase: sl()));
}
