import 'package:equatable/equatable.dart';

/// The signed-in account as the auth server knows it.
final class AuthUser extends Equatable {
  const AuthUser({required this.id, this.phone});

  final String id;

  /// The account's phone in international form, without the +, as the auth
  /// server keeps it.
  final String? phone;

  @override
  List<Object?> get props => [id, phone];
}
