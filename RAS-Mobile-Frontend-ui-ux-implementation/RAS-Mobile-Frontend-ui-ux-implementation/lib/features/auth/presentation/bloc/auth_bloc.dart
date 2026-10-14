import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/api_exception.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required LoginUseCase loginUseCase,
    required AuthRepository authRepository,
  }) : _loginUseCase = loginUseCase,
       _authRepository = authRepository,
       super(const AuthState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<ClearAuthError>(_onClearAuthError);
    on<SessionRestoreRequested>(_onRestoreSession);
  }

  final LoginUseCase _loginUseCase;
  final AuthRepository _authRepository;

  Future<void> _onRestoreSession(
    SessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final session = await _authRepository.getCurrentSession();
      emit(
        session == null
            ? const AuthState(status: AuthStatus.unauthenticated)
            : state.copyWith(
                status: AuthStatus.authenticated,
                session: session,
              ),
      );
    } catch (_) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    try {
      final session = await _loginUseCase(
        identifier: event.identifier,
        password: event.password,
      );
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          session: session,
          errorMessage: null,
          remainingAttempts: 3,
        ),
      );
    } catch (e) {
      final isCredentialFailure = e is ApiException && e.statusCode == 401;
      final nextAttempts = isCredentialFailure && state.remainingAttempts > 1
          ? state.remainingAttempts - 1
          : state.remainingAttempts;
      final msg = e is FormatException
          ? e.message
          : e is ApiException
          ? arabicApiMessage(e)
          : 'تعذر الاتصال بالخدمة. تحقق من الشبكة وحاول مرة أخرى.';
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: msg,
          remainingAttempts: nextAttempts,
        ),
      );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onClearAuthError(ClearAuthError event, Emitter<AuthState> emit) {
    emit(state.copyWith(errorMessage: null));
  }
}
