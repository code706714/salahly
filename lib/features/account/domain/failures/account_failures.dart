import 'package:salahly/core/error/failure.dart';

/// A transfer is still waiting to be checked, so deleting the account
/// would lose the money sent.
final class PendingTransferFailure extends Failure {
  const PendingTransferFailure();
}

/// Money held for a job is not settled yet, so deleting the account would
/// lose the proof and the payout details the team needs.
final class ActiveEscrowFailure extends Failure {
  const ActiveEscrowFailure();
}

/// Deleting the account needs a sign-in from the last 15 minutes.
final class RecentLoginRequiredFailure extends Failure {
  const RecentLoginRequiredFailure();
}
