import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/login_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required LoginUseCase loginUseCase})
    : _loginUseCase = loginUseCase,
      super(const AuthState()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<ClearAuthError>(_onClearAuthError);
    on<SessionRestored>(
      (event, emit) => emit(
        AuthState(status: AuthStatus.authenticated, session: event.session),
      ),
    );
  }

  final LoginUseCase _loginUseCase;

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
      final nextAttempts = state.remainingAttempts > 1
          ? state.remainingAttempts - 1
          : 0;
      final msg = e is FormatException
          ? e.message
          : 'فشل تسجيل الدخول. يرجى التحقق من البيانات';
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
    try {
      await _loginUseCase.logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          clearSession: true,
          errorMessage: e is FormatException ? e.message : 'تعذر تسجيل الخروج',
        ),
      );
    }

  }


  void _onClearAuthError(ClearAuthError event, Emitter<AuthState> emit) {
    emit(state.copyWith(errorMessage: null));
  }
}
