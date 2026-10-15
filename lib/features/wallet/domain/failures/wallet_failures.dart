import 'package:salahly/core/error/failure.dart';

/// The amount is under the smallest withdrawal.
final class AmountTooSmallFailure extends Failure {
  const AmountTooSmallFailure();
}

/// The amount is more than the wallet holds.
final class InsufficientBalanceFailure extends Failure {
  const InsufficientBalanceFailure();
}

/// The name on the account isn't usable.
final class InvalidHolderFailure extends Failure {
  const InvalidHolderFailure();
}

/// The number or address isn't valid for the method.
final class InvalidWithdrawalAccountFailure extends Failure {
  const InvalidWithdrawalAccountFailure();
}
