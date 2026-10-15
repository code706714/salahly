import 'package:equatable/equatable.dart';

/// Why an operation failed, in terms the UI can act on.
///
/// Features add their own subclasses next to their domain; pages map the
/// ones they care about to messages and fall back to a generic one.
abstract base class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => [];
}

/// The device is offline or the server could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The server refused because too many requests were made recently.
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure();
}

/// The team suspended this account, so the server refuses everything.
final class AccountSuspendedFailure extends Failure {
  const AccountSuspendedFailure();
}

/// The chosen area is closed for now.
final class AreaClosedFailure extends Failure {
  const AreaClosedFailure();
}

/// Anything the app did not anticipate. [cause] is kept for logging only.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([this.cause]);

  final Object? cause;

  @override
  List<Object?> get props => [cause];
}
