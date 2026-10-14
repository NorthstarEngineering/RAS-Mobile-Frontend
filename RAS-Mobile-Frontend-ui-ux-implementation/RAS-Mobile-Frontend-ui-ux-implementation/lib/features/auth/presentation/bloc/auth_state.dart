import 'package:equatable/equatable.dart';
import '../../domain/entities/user_session.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.session,
    this.errorMessage,
    this.remainingAttempts = 3,
  });

  final AuthStatus status;
  final UserSession? session;
  final String? errorMessage;
  final int remainingAttempts;

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated =>
      status == AuthStatus.authenticated && session != null;

  AuthState copyWith({
    AuthStatus? status,
    UserSession? session,
    String? errorMessage,
    int? remainingAttempts,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: errorMessage,
      remainingAttempts: remainingAttempts ?? this.remainingAttempts,
    );
  }

  @override
  List<Object?> get props => [status, session, errorMessage, remainingAttempts];
}
