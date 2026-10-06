import 'package:salahly/core/error/failure.dart';

/// The pack isn't on sale (anymore) for this person.
final class PackNotFoundFailure extends Failure {
  const PackNotFoundFailure();
}

/// The way to transfer the money isn't available now.
final class MethodUnavailableFailure extends Failure {
  const MethodUnavailableFailure();
}

/// The account the money came from isn't a valid number or address.
final class InvalidSenderFailure extends Failure {
  const InvalidSenderFailure();
}

/// The server has no such screenshot from this person, or it was used
/// for another transfer.
final class InvalidScreenshotFailure extends Failure {
  const InvalidScreenshotFailure();
}

/// The pack costs something else than what the person saw and transferred.
final class PriceChangedFailure extends Failure {
  const PriceChangedFailure();
}

/// Two transfers are already waiting for review.
final class TooManyPendingFailure extends Failure {
  const TooManyPendingFailure();
}
