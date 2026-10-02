import 'package:salahly/core/error/failure.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The message for failures any screen can hit. Screens check their own
/// failure types first and fall back to this.
String commonFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.errorNetwork,
    RateLimitedFailure() => l10n.errorRateLimited,
    _ => l10n.errorUnexpected,
  };
}
