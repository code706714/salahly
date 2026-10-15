import 'package:salahly/core/error/failure.dart';

/// Online payment can't be started now: the provider is down or not set up.
final class PaymentsUnavailableFailure extends Failure {
  const PaymentsUnavailableFailure();
}
