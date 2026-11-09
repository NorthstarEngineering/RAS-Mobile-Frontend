import 'package:equatable/equatable.dart';
import '../../domain/entities/user_session.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({required this.identifier, required this.password});

  final String identifier;
  final String password;

  @override
  List<Object?> get props => [identifier, password];
}

class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}

class ClearAuthError extends AuthEvent {
  const ClearAuthError();
}

class SessionRestored extends AuthEvent {
  const SessionRestored(this.session);

  final UserSession session;

  @override
  List<Object?> get props => [session];
}
