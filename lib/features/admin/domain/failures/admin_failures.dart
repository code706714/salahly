import 'package:salahly/core/error/failure.dart';

/// The signed-in account is not an admin. The server decides this; the
/// console only reports it.
final class AdminRequiredFailure extends Failure {
  const AdminRequiredFailure();
}

/// What was asked for is not there (any more).
final class AdminNotFoundFailure extends Failure {
  const AdminNotFoundFailure();
}

/// The submission was already reviewed the other way, so it can't be
/// reviewed again.
final class NotPendingFailure extends Failure {
  const NotPendingFailure();
}

/// The server refused a value or a filter the console sent.
final class InvalidInputFailure extends Failure {
  const InvalidInputFailure();
}

/// An item with the same identity exists: a pack with the same number of
/// uses on sale, or an area with the same id.
final class DuplicateFailure extends Failure {
  const DuplicateFailure();
}

/// The change would leave nothing on sale for a role, or no account to send
/// money to.
final class LastActiveFailure extends Failure {
  const LastActiveFailure();
}

/// Admins can not be suspended.
final class CannotSuspendAdminFailure extends Failure {
  const CannotSuspendAdminFailure();
}
