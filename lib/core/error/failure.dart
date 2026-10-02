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

/// Anything the app did not anticipate. [cause] is kept for logging only.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([this.cause]);

  final Object? cause;

  @override
  List<Object?> get props => [cause];
}
