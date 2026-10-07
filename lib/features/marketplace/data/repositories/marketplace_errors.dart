import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How long a request photo link works, in seconds.
const photoLinkSeconds = 3600;

/// The failure for an error the marketplace functions raise by name, or
/// null for anything else.
Failure? marketplaceFailureFrom(Object error) {
  if (error is! PostgrestException) return null;
  return switch (error.message) {
    'no_credits' => const NoCreditsFailure(),
    'request_closed' => const RequestClosedFailure(),
    'not_found' || 'invalid_address' => const MarketplaceNotFoundFailure(),
    'technician_unavailable' => const TechnicianUnavailableFailure(),
    'offer_expired' => const OfferExpiredFailure(),
    'invalid_time' => const InvalidTimeFailure(),
    'too_late' => const TooLateToCancelFailure(),
    'no_price_change' => const PriceChangeGoneFailure(),
    'already_offered' ||
    'already_reviewed' ||
    'already_complained' => const AlreadySentFailure(),
    'limit_reached' => const AddressLimitFailure(),
    'not_confirmed' => const ArrivalNotReadyFailure(),
    _ => null,
  };
}
