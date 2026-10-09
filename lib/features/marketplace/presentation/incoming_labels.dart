import 'package:intl/intl.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The request's name, "تكييف مش بيبرّد", or only its problem while the
/// category names aren't loaded.
String incomingTitle(
  AppLocalizations l10n,
  IncomingRequest request, {
  required String? category,
}) => category == null
    ? requestIssueLabel(l10n, request.issue)
    : requestTitle(l10n, request.issue, category: category);

/// "من 20 دقيقة": how long ago a request was sent.
String sentAgoLabel(
  AppLocalizations l10n,
  DateTime sentAt, {
  required DateTime now,
}) {
  final elapsed = now.difference(sentAt);
  if (elapsed.inMinutes < 1) return l10n.incomingAgoNow;
  if (elapsed.inHours < 1) return l10n.incomingAgoMinutes(elapsed.inMinutes);
  if (elapsed.inDays < 1) return l10n.incomingAgoHours(elapsed.inHours);
  return l10n.incomingAgoDays(elapsed.inDays);
}

final _kilometers = NumberFormat('#,##0.#', 'en');

/// "2.4 كم منك".
String distanceLabel(AppLocalizations l10n, double km) =>
    l10n.incomingDistance(_kilometers.format(km));

/// The day and window asked for: "بكره السبت، من 12 لـ 3 الضهر".
String requestDayLabel(
  AppLocalizations l10n,
  DateTime day,
  RequestWindow window, {
  required DateTime today,
}) =>
    '${_dayName(l10n, day, today: today)}، '
    '${requestRangeLabel(l10n, window)}';

/// "بكره السبت" close by, "الاتنين 6 أكتوبر" further on.
String _dayName(
  AppLocalizations l10n,
  DateTime day, {
  required DateTime today,
}) => switch (CalendarDate.daysBetween(today, day)) {
  0 || 1 => '${dayLabel(l10n, day, today: today)} ${weekdayName(day)}',
  _ => weekdayDate(day),
};

/// An arrival time to pick, short: "بكره 12:00", "السبت 1:30".
String arrivalChoiceLabel(
  AppLocalizations l10n,
  DateTime at, {
  required DateTime today,
}) {
  final day = switch (CalendarDate.daysBetween(today, at)) {
    0 || 1 => dayLabel(l10n, at, today: today),
    _ => weekdayName(at),
  };
  return '$day ${clockTime(at)}';
}

/// When the technician said they'd come: "هتوصل بكره 12:00 الضهر".
String arrivalLabel(
  AppLocalizations l10n,
  DateTime at, {
  required DateTime today,
}) => l10n.offerFormArriveAt(
  '${dayLabel(l10n, at, today: today)} ${timeLabel(l10n, at)}',
);

/// Where a request sent to the technician stands for them.
enum IncomingStanding {
  /// Waiting for their offer.
  open,

  /// Their offer waits for the consumer's pick.
  offerSent,

  /// The consumer picked their offer.
  chosen,

  /// The consumer picked another technician.
  notChosen,

  /// They took their offer back.
  withdrawn,
  cancelled,
  expired,

  /// It has its five offers.
  full,

  /// Closed for a reason not known here.
  closed;

  /// Still in play: open, or with their offer waiting.
  bool get isLive => this == open || this == offerSent;

  /// Over without this technician.
  bool get isClosed => !isLive && this != chosen;
}

/// Where [request] stands for this technician; [closedSince] when it was
/// found closed without knowing why.
IncomingStanding standingOf(
  IncomingRequest request, {
  bool closedSince = false,
}) {
  final offer = request.myOffer;
  if (offer?.status == OfferStatus.accepted) return IncomingStanding.chosen;
  if (offer?.status == OfferStatus.withdrawn) return IncomingStanding.withdrawn;
  return switch (request.status) {
    RequestStatus.assigned => IncomingStanding.notChosen,
    _ when offer?.status == OfferStatus.notChosen => IncomingStanding.notChosen,
    RequestStatus.cancelled => IncomingStanding.cancelled,
    RequestStatus.expired => IncomingStanding.expired,
    RequestStatus.open when offer != null => IncomingStanding.offerSent,
    RequestStatus.open when request.offerCount >= IncomingRequest.maxOffers =>
      IncomingStanding.full,
    RequestStatus.open when closedSince => IncomingStanding.closed,
    RequestStatus.open => IncomingStanding.open,
  };
}

/// [standing] in words, about [request]'s consumer: "بعتّ عرضك · 350 ج.م",
/// "اختارت فني تاني"; null while the request waits for an offer.
String? standingLabel(
  AppLocalizations l10n,
  IncomingRequest request,
  IncomingStanding standing,
) {
  final honorific = request.consumerHonorific.name;
  return switch (standing) {
    IncomingStanding.open => null,
    IncomingStanding.offerSent => l10n.incomingMyOffer(
      formatPounds(request.myOffer!.pricePiastres),
    ),
    IncomingStanding.chosen => l10n.incomingOfferChosen(honorific),
    IncomingStanding.notChosen => l10n.incomingOfferNotChosen(honorific),
    IncomingStanding.withdrawn => l10n.incomingOfferWithdrawn,
    IncomingStanding.cancelled => l10n.incomingClosedCancelled(honorific),
    IncomingStanding.expired => l10n.incomingClosedExpired,
    IncomingStanding.full => l10n.incomingClosedFull,
    IncomingStanding.closed => l10n.incomingClosed,
  };
}
