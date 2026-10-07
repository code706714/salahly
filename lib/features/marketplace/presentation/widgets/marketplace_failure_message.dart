import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What to tell a consumer whose request, offer pick or rating failed,
/// addressed by [honorific].
String consumerFailureMessage(
  AppLocalizations l10n,
  Failure failure, {
  required String honorific,
}) {
  return switch (failure) {
    NoCreditsFailure() => l10n.consumerNoCredits(honorific),
    RequestClosedFailure() => l10n.consumerRequestClosed,
    MarketplaceNotFoundFailure() => l10n.marketplaceNotFound,
    TechnicianUnavailableFailure() => l10n.consumerTechnicianUnavailable(
      honorific,
    ),
    OfferExpiredFailure() => l10n.consumerOfferExpired(honorific),
    TooLateToCancelFailure() => l10n.consumerTooLateToCancel(honorific),
    PriceChangeGoneFailure() => l10n.consumerPriceChangeGone(honorific),
    AlreadySentFailure() => l10n.consumerAlreadySent,
    AddressLimitFailure() => l10n.consumerAddressLimit(honorific),
    NetworkFailure() => l10n.consumerErrorNetwork(honorific),
    RateLimitedFailure() => l10n.consumerErrorRateLimited(honorific),
    _ => l10n.consumerErrorUnexpected(honorific),
  };
}

/// What to tell a technician whose offer failed.
String technicianOfferFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    NoCreditsFailure() => l10n.technicianNoCredits,
    RequestClosedFailure() => l10n.technicianRequestClosed,
    MarketplaceNotFoundFailure() => l10n.marketplaceNotFound,
    InvalidTimeFailure() => l10n.technicianInvalidTime,
    AlreadySentFailure() => l10n.technicianAlreadyOffered,
    _ => commonFailureMessage(l10n, failure),
  };
}

/// What to tell a technician whose "قربت أوصل" didn't reach the consumer.
String arrivalFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    NetworkFailure() => l10n.arrivalNeedsInternet,
    ArrivalNotReadyFailure() => l10n.arrivalNotReady,
    ArrivalLimitFailure() => l10n.arrivalLimit,
    MarketplaceNotFoundFailure() => l10n.marketplaceNotFound,
    _ => commonFailureMessage(l10n, failure),
  };
}
