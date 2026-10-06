import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What to tell someone whose transfer could not be sent, addressed by
/// [honorific] ('other' for a technician).
String buyUsesFailureMessage(
  AppLocalizations l10n,
  Failure failure, {
  required UserRole role,
  required String honorific,
}) {
  return switch (failure) {
    PriceChangedFailure() => l10n.buyUsesPriceChanged(honorific),
    TooManyPendingFailure() => l10n.buyUsesTooManyPending(honorific),
    PackNotFoundFailure() => l10n.buyUsesPackGone(honorific),
    MethodUnavailableFailure() => l10n.buyUsesMethodGone(honorific),
    InvalidSenderFailure() => l10n.buyUsesInvalidSender(honorific),
    InvalidScreenshotFailure() => l10n.buyUsesInvalidScreenshot(honorific),
    UploadLimitFailure() => l10n.buyUsesUploadLimit(honorific),
    UnsupportedPhotoFailure() => l10n.buyUsesPhotoRejected(honorific),
    _ when role == UserRole.consumer => consumerFailureMessage(
      l10n,
      failure,
      honorific: honorific,
    ),
    _ => commonFailureMessage(l10n, failure),
  };
}
