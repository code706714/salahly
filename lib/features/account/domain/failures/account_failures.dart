import 'package:salahly/core/error/failure.dart';

/// A transfer is still waiting to be checked, so deleting the account
/// would lose the money sent.
final class PendingTransferFailure extends Failure {
  const PendingTransferFailure();
}

/// Deleting the account needs a sign-in from the last 15 minutes.
final class RecentLoginRequiredFailure extends Failure {
  const RecentLoginRequiredFailure();
}
