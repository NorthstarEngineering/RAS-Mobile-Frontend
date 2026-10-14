import 'package:get_it/get_it.dart';

import '../../features/auth/data/repositories/api_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/employees/data/repositories/api_employee_repository.dart';
import '../../features/employees/domain/repositories/employee_repository.dart';
import '../../features/branches/data/repositories/api_branch_repository.dart';
import '../../features/menu/data/repositories/mock_menu_repository.dart';
import '../../features/menu/domain/repositories/menu_repository.dart';
import '../../features/pricing/data/repositories/mock_pricing_repository.dart';
import '../../features/pricing/domain/repositories/pricing_repository.dart';
import '../network/api_services.dart';
import '../network/ras_api.dart';

final sl = GetIt.instance;
final getIt = sl;

Future<void> initServiceLocator() async {
  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => ApiAuthRepository());
  sl.registerLazySingleton(() => ApiServices(sl<ApiAuthRepository>()));
  sl.registerLazySingleton(() => RasApi(sl<ApiServices>()));
  sl.registerLazySingleton(
    () => ApiBranchRepository(sl<ApiServices>().branches),
  );
  sl.registerLazySingleton<EmployeeRepository>(
    () => ApiEmployeeRepository(sl<ApiServices>().attendance),
  );
  sl.registerLazySingleton<MenuRepository>(() => MockMenuRepository());
  sl.registerLazySingleton<PricingRepository>(() => MockPricingRepository());

  // UseCases
  sl.registerLazySingleton(() => LoginUseCase(sl()));

  // BLoCs
  sl.registerLazySingleton(
    () => AuthBloc(loginUseCase: sl(), authRepository: sl()),
  );
}
