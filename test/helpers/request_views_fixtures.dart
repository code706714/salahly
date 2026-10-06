import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

import 'marketplace_fixtures.dart';

// Requests for the waiting, offers and closed request screens. Those
// screens read the real clock, so these requests are dated from now.

/// Today's midnight.
DateTime get today => CalendarDate.of(DateTime.now());

/// Midnight [days] days from today.
DateTime dayFromToday(int days) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days);
}

/// [hour]:[minute] tomorrow.
DateTime tomorrowAt(int hour, [int minute = 0]) {
  final day = dayFromToday(1);
  return DateTime(day.year, day.month, day.day, hour, minute);
}

/// The design's three offers, coming tomorrow: Yasser (offer-1, the
/// nearest), Mahmoud (offer-2) and Ahmed (offer-3, the cheapest).
List<RequestOffer> liveOffers() => [
  testOffer(
    pricePiastres: 40000,
    arriveAt: tomorrowAt(12, 30),
    note: 'غالباً محتاج تنظيف وشحن بسيط، هكشف وأقولك.',
    distanceKm: 1.2,
    technician: testTechnicianCard(
      id: 'tech-2',
      name: 'ياسر عبد الحميد',
      rating: 4.9,
      reviewCount: 31,
      jobsDone: 40,
    ),
  ),
  testOffer(
    id: 'offer-2',
    arriveAt: tomorrowAt(12),
    note: 'السعر شامل الكشف والتنظيف. لو محتاج فريون هقولك قبل ما أبدأ.',
  ),
  testOffer(
    id: 'offer-3',
    pricePiastres: 30000,
    arriveAt: tomorrowAt(14, 30),
    note: 'كشف وتنظيف داخلي وخارجي.',
    distanceKm: 4.1,
    technician: testTechnicianCard(
      id: 'tech-3',
      name: 'أحمد رمضان',
      rating: 4.6,
      reviewCount: 58,
      jobsDone: 97,
    ),
  ),
];

/// A request for tomorrow, sent [sentAgo] ago; open with no offers unless
/// told otherwise.
RequestDetails liveRequest({
  String id = 'request-1',
  RequestIssue issue = RequestIssue.notCooling,
  RequestStatus status = RequestStatus.open,
  List<RequestOffer> offers = const [],
  RequestWindow window = RequestWindow.noon,
  DateTime? day,
  Duration sentAgo = const Duration(minutes: 40),
  int sentTo = 5,
  int seenBy = 3,
  bool widened = false,
  UserRole? cancelledBy,
  String? chosenOfferId,
}) {
  final requested = day ?? dayFromToday(1);
  return RequestDetails(
    id: id,
    categoryId: 'ac',
    issue: issue,
    description: 'التكييف شغال بس الهوا مش ساقع.',
    areaId: 'nasr_city',
    addressLabel: testHome.label,
    addressDetails: testHome.details,
    day: requested,
    window: window,
    expiresAt: window.endOn(requested),
    status: status,
    cancelledBy: cancelledBy,
    cancelledAt: cancelledBy == null ? null : DateTime.now(),
    widened: widened,
    createdAt: DateTime.now().subtract(sentAgo),
    sentTo: sentTo,
    seenBy: seenBy,
    offers: offers,
    chosenOfferId: chosenOfferId,
    hasOpenComplaint: false,
  );
}
