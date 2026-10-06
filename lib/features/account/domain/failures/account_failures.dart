import 'package:salahly/core/error/failure.dart';

/// A transfer is still waiting to be checked, so deleting the account
/// would lose the money sent.
final class PendingTransferFailure extends Failure {
  const PendingTransferFailure();
}
