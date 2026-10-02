import 'package:equatable/equatable.dart';

/// The signed-in account as the auth server knows it.
final class AuthUser extends Equatable {
  const AuthUser({required this.id});

  final String id;

  @override
  List<Object?> get props => [id];
}
