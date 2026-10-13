import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What to tell a consumer whose payment could not be sent or answered.
String escrowFailureMessage(
  AppLocalizations l10n,
  Failure failure, {
  required String honorific,
}) {
  return switch (failure) {
    EscrowUnavailableFailure() => l10n.escrowFailureUnavailable,
    AlreadySecuredFailure() => l10n.escrowFailureAlreadySecured,
    InvalidReasonFailure() => l10n.escrowFailureInvalidReason,
    MethodUnavailableFailure() => l10n.buyUsesMethodGone(honorific),
    InvalidSenderFailure() => l10n.buyUsesInvalidSender(honorific),
    InvalidScreenshotFailure() => l10n.buyUsesInvalidScreenshot(honorific),
    UploadLimitFailure() => l10n.buyUsesUploadLimit(honorific),
    UnsupportedPhotoFailure() => l10n.buyUsesPhotoRejected(honorific),
    _ => consumerFailureMessage(l10n, failure, honorific: honorific),
  };
}
