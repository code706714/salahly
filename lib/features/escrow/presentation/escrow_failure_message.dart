import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What to tell a consumer whose payment could not be started or answered.
String escrowFailureMessage(
  AppLocalizations l10n,
  Failure failure, {
  required String honorific,
}) {
  return switch (failure) {
    EscrowUnavailableFailure() => l10n.escrowFailureUnavailable,
    AlreadySecuredFailure() => l10n.escrowFailureAlreadySecured,
    PaymentsUnavailableFailure() => l10n.paymentsUnavailable(honorific),
    InvalidReasonFailure() => l10n.escrowFailureInvalidReason,
    _ => consumerFailureMessage(l10n, failure, honorific: honorific),
  };
}
