import 'package:intl/intl.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What a notification says: a `title` and, when there is something more,
/// a `body`.
typedef NotificationText = ({String title, String? body});

/// Builds the text of [notification] from its kind and what it carries.
///
/// A consumer's copy is addressed by `honorific`; a technician's is
/// masculine, so they pass 'other'. Copy about a consumer, shown to a
/// technician, follows the consumer's own honorific. Whatever is missing
/// (the request was deleted since) falls back to plain words.
NotificationText notificationText(
  AppLocalizations l10n,
  AppNotification notification, {
  required UserRole role,
  required String honorific,
  required DateTime today,
  String? categoryName,
  String? areaName,
}) {
  final technician =
      notification.technicianName ?? l10n.notifTechnicianFallback;
  final gender = notification.consumerHonorific?.name ?? 'other';
  final consumer =
      notification.consumerName ?? l10n.notifConsumerFallback(gender);
  final request = _requestName(l10n, notification, categoryName);
  final price = notification.pricePiastres;
  final arriveAt = notification.arriveAt;
  final arrival = arriveAt == null
      ? null
      : arrivalChoiceLabel(l10n, arriveAt, today: today);
  final pounds = price == null ? null : l10n.pounds(formatPounds(price));
  final distance = notification.distanceKm;
  final day = notification.day;
  final window = notification.window;
  final uses = notification.topupUses;
  final offerDetails = _join([?arrival, ?pounds]);

  return switch (notification.kind) {
    NotificationKind.offerReceived => (
      title: l10n.notifOfferReceived,
      body: _join([?notification.technicianName, ?pounds, ?arrival]),
    ),
    NotificationKind.jobConfirmed => (
      title: l10n.notifJobConfirmed(technician),
      body: request,
    ),
    NotificationKind.jobStarted => (
      title: l10n.notifJobStarted(technician),
      body: request,
    ),
    NotificationKind.jobFinished => (
      title: l10n.notifJobFinished(technician),
      body: l10n.notifJobFinishedBody,
    ),
    NotificationKind.priceChange => (
      title: l10n.notifPriceChange(technician),
      body: l10n.notifPriceChangeBody(honorific),
    ),
    NotificationKind.requestCancelledByTechnician => (
      title: l10n.notifCancelledByTechnician(technician),
      body: l10n.notifCancelledByTechnicianBody(honorific),
    ),
    NotificationKind.requestExpired => (
      title: l10n.notifExpired,
      body: l10n.notifExpiredBody(honorific),
    ),
    NotificationKind.newRequest => (
      title: areaName == null
          ? l10n.notifNewRequest
          : l10n.notifNewRequestIn(areaName),
      body: _join([
        ?request,
        ?(distance == null ? null : distanceLabel(l10n, distance)),
        ?(day == null || window == null
            ? null
            : _askedFor(l10n, day, window, today: today)),
      ]),
    ),
    NotificationKind.offerPicked => (
      title: l10n.notifOfferPicked(gender, consumer),
      body: [
        ?(offerDetails == null ? null : '$offerDetails.'),
        l10n.notifOfferPickedBody(gender),
      ].join(' '),
    ),
    NotificationKind.offerNotPicked => (
      title: l10n.notifOfferNotPicked(gender, consumer),
      body: l10n.notifOfferNotPickedBody,
    ),
    NotificationKind.requestCancelledByConsumer => (
      title: l10n.notifCancelledByConsumer(gender, consumer),
      body: l10n.notifCancelledByConsumerBody,
    ),
    NotificationKind.verificationApproved => (
      title: l10n.notifVerificationApproved,
      body: l10n.notifVerificationApprovedBody,
    ),
    NotificationKind.verificationRejected => (
      title: l10n.notifVerificationRejected,
      body: l10n.notifVerificationRejectedBody,
    ),
    NotificationKind.topupApproved => (
      title: l10n.notifTopupApproved,
      body: uses == null
          ? null
          : switch (role) {
              UserRole.consumer => l10n.notifTopupApprovedConsumer(uses),
              UserRole.technician => l10n.notifTopupApprovedTechnician(uses),
            },
    ),
    NotificationKind.topupRejected => (
      title: l10n.notifTopupRejected,
      body: l10n.notifTopupRejectedBody(honorific),
    ),
  };
}

/// The day and part of the day asked for, short: "بكره الضهر".
String _askedFor(
  AppLocalizations l10n,
  DateTime day,
  RequestWindow window, {
  required DateTime today,
}) {
  final part = switch (window) {
    RequestWindow.morning => PartOfDay.morning,
    RequestWindow.noon => PartOfDay.noon,
    RequestWindow.afternoon => PartOfDay.afternoon,
    RequestWindow.evening => PartOfDay.sunset,
    RequestWindow.anyTime => null,
  };
  final label = dayLabel(l10n, day, today: today);
  return part == null ? label : '$label ${partOfDayLabel(l10n, part)}';
}

/// "تكييف مش بيبرّد", or null when the request is gone.
String? _requestName(
  AppLocalizations l10n,
  AppNotification notification,
  String? categoryName,
) {
  final issue = notification.issue;
  if (issue == null) return null;
  return categoryName == null
      ? requestIssueLabel(l10n, issue)
      : requestTitle(l10n, issue, category: categoryName);
}

/// The parts joined with " · ", or null when there are none.
String? _join(List<String> parts) => parts.isEmpty ? null : parts.join(' · ');

/// When it happened, short: "دلوقتي", "20 د", "ساعة", "3 س", "9:05 ص",
/// "امبارح", a weekday within the week, else the date.
String notificationTimeLabel(
  AppLocalizations l10n,
  DateTime at, {
  required DateTime now,
}) {
  final elapsed = now.difference(at);
  if (elapsed < const Duration(minutes: 1)) return l10n.notifAgoNow;
  if (elapsed < const Duration(hours: 1)) {
    return l10n.notifAgoMinutes(elapsed.inMinutes);
  }
  final days = CalendarDate.daysBetween(now, at).abs();
  if (days == 0) {
    return elapsed < const Duration(hours: 6)
        ? l10n.notifAgoHours(elapsed.inHours)
        : '${clockTime(at)} ${at.hour < 12 ? l10n.notifAm : l10n.notifPm}';
  }
  if (days == 1) return l10n.notifYesterday;
  if (days < 7) return weekdayName(at);
  return DateFormat('d MMMM', 'ar').format(at);
}

/// The heading a notification sits under: today, yesterday or earlier.
String notificationDayHeading(
  AppLocalizations l10n,
  DateTime at, {
  required DateTime now,
}) => switch (CalendarDate.daysBetween(now, at).abs()) {
  0 => l10n.notifToday,
  1 => l10n.notifYesterday,
  _ => l10n.notifEarlier,
};

/// The screen a notification opens, on [role]'s side of the app.
String notificationRoute(AppNotification notification, UserRole role) {
  final requestId = notification.requestId;
  if (notification.kind.isAboutTopup) return AppRoutes.balanceFor(role);
  if (notification.kind.isAboutVerification) {
    return AppRoutes.technicianAccount;
  }
  return switch (role) {
    UserRole.consumer =>
      requestId == null
          ? AppRoutes.consumerRequests
          : AppRoutes.request(requestId),
    UserRole.technician =>
      requestId == null
          ? AppRoutes.incomingRequests
          : AppRoutes.incomingRequest(requestId),
  };
}
