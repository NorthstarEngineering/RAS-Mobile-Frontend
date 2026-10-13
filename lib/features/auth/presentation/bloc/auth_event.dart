import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({
    required this.identifier,
    required this.password,
  });

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
