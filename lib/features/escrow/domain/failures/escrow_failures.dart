import 'package:salahly/core/error/failure.dart';

/// The request can't be guaranteed or answered now: it isn't the person's,
/// the job already started, or there is no payment in the right state.
final class EscrowUnavailableFailure extends Failure {
  const EscrowUnavailableFailure();
}

/// A payment is already being checked or held for the request.
final class AlreadySecuredFailure extends Failure {
  const AlreadySecuredFailure();
}

/// The name on the payout account isn't usable.
final class InvalidHolderFailure extends Failure {
  const InvalidHolderFailure();
}

/// The payout account isn't a valid number or address.
final class InvalidPayoutAccountFailure extends Failure {
  const InvalidPayoutAccountFailure();
}

/// The reason for the objection is empty or too long.
final class InvalidReasonFailure extends Failure {
  const InvalidReasonFailure();
}
