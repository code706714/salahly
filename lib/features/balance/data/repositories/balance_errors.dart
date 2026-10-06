import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The failure for an error `submit_topup` raises by name, or null for
/// anything else.
Failure? balanceFailureFrom(Object error) {
  if (error is! PostgrestException) return null;
  return switch (error.message) {
    'pack_not_found' => const PackNotFoundFailure(),
    'method_unavailable' => const MethodUnavailableFailure(),
    'invalid_sender' => const InvalidSenderFailure(),
    'invalid_screenshot' => const InvalidScreenshotFailure(),
    'price_changed' => const PriceChangedFailure(),
    'too_many_pending' => const TooManyPendingFailure(),
    _ => null,
  };
}
