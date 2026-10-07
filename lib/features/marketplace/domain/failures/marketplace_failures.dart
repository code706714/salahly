import 'package:salahly/core/error/failure.dart';

/// No uses left: a consumer can't send a request, a technician can't send
/// an offer.
final class NoCreditsFailure extends Failure {
  const NoCreditsFailure();
}

/// The request no longer takes offers or picks: it was cancelled, expired,
/// already has a technician, or has its three offers.
final class RequestClosedFailure extends Failure {
  const RequestClosedFailure();
}

/// The request, offer or address doesn't exist for this user.
final class MarketplaceNotFoundFailure extends Failure {
  const MarketplaceNotFoundFailure();
}

/// The picked technician ran out of uses since sending the offer.
final class TechnicianUnavailableFailure extends Failure {
  const TechnicianUnavailableFailure();
}

/// The time the offer named has passed.
final class OfferExpiredFailure extends Failure {
  const OfferExpiredFailure();
}

/// The day or time is outside what the request allows.
final class InvalidTimeFailure extends Failure {
  const InvalidTimeFailure();
}

/// The work already started, so the request can't be cancelled.
final class TooLateToCancelFailure extends Failure {
  const TooLateToCancelFailure();
}

/// The price change was withdrawn or replaced before the answer arrived.
final class PriceChangeGoneFailure extends Failure {
  const PriceChangeGoneFailure();
}

/// This was already sent once: an offer, a rating or an open complaint.
final class AlreadySentFailure extends Failure {
  const AlreadySentFailure();
}

/// The address book holds at most ten addresses.
final class AddressLimitFailure extends Failure {
  const AddressLimitFailure();
}

/// The job isn't confirmed on the server (yet, or any more), so the
/// consumer can't be told the technician is almost there.
final class ArrivalNotReadyFailure extends Failure {
  const ArrivalNotReadyFailure();
}

/// The consumer was already told several times for this request.
final class ArrivalLimitFailure extends Failure {
  const ArrivalLimitFailure();
}
