import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';

import '../../../helpers/incoming_fixtures.dart';
import '../../../pump_app.dart';

void main() {
  final friday = DateTime(2026, 10, 2, 20);

  setUpAll(() => initializeDateFormatting('ar'));

  test('names a request by its problem and category, or the problem', () {
    final request = testIncoming(issue: RequestIssue.leaking);
    expect(incomingTitle(l10n, request, category: 'تكييف'), 'تكييف بينقّط مية');
    expect(incomingTitle(l10n, request, category: null), isNotEmpty);
  });

  test('says how long ago a request was sent', () {
    String ago(Duration elapsed) =>
        sentAgoLabel(l10n, friday.subtract(elapsed), now: friday);
    expect(ago(const Duration(seconds: 30)), 'لسه حالاً');
    expect(ago(const Duration(minutes: 1)), 'من دقيقة');
    expect(ago(const Duration(minutes: 20)), 'من 20 دقيقة');
    expect(ago(const Duration(minutes: 5)), 'من 5 دقايق');
    expect(ago(const Duration(hours: 2)), 'من ساعتين');
    expect(ago(const Duration(days: 3)), 'من 3 أيام');
  });

  test('says how far a request is', () {
    expect(distanceLabel(l10n, 2.4), '2.4 كم منك');
    expect(distanceLabel(l10n, 3), '3 كم منك');
    expect(distanceLabel(l10n, 12.36), '12.4 كم منك');
  });

  test('names the day and window asked for', () {
    expect(
      requestDayLabel(
        l10n,
        DateTime(2026, 10, 3),
        RequestWindow.noon,
        today: friday,
      ),
      'بكره السبت، من 12 لـ 3 الضهر',
    );
    expect(
      requestDayLabel(
        l10n,
        DateTime(2026, 10, 2),
        RequestWindow.evening,
        today: friday,
      ),
      'النهارده الجمعة، من 6 لـ 9 بالليل',
    );
    expect(
      requestDayLabel(
        l10n,
        DateTime(2026, 10, 5),
        RequestWindow.morning,
        today: friday,
      ),
      startsWith('الاثنين 5 أكتوبر، '),
    );
  });

  test('names an arrival time to pick and the one offered', () {
    final noon = DateTime(2026, 10, 3, 12, 30);
    expect(arrivalChoiceLabel(l10n, noon, today: friday), 'بكره 12:30');
    expect(
      arrivalChoiceLabel(l10n, DateTime(2026, 10, 5, 9), today: friday),
      'الاثنين 9:00',
    );
    expect(arrivalLabel(l10n, noon, today: friday), 'هتوصل بكره 12:30 الضهر');
  });

  group('standing', () {
    test('open, offered, picked or not', () {
      expect(standingOf(testIncoming()), IncomingStanding.open);
      expect(
        standingOf(testIncoming(myOffer: testMyOffer())),
        IncomingStanding.offerSent,
      );
      expect(
        standingOf(
          testIncoming(
            status: RequestStatus.assigned,
            myOffer: testMyOffer(status: OfferStatus.accepted),
          ),
        ),
        IncomingStanding.chosen,
      );
      expect(
        standingOf(testIncoming(status: RequestStatus.assigned)),
        IncomingStanding.notChosen,
      );
      expect(
        standingOf(
          testIncoming(myOffer: testMyOffer(status: OfferStatus.notChosen)),
        ),
        IncomingStanding.notChosen,
      );
    });

    test('closed and why', () {
      expect(
        standingOf(testIncoming(status: RequestStatus.cancelled)),
        IncomingStanding.cancelled,
      );
      expect(
        standingOf(testIncoming(status: RequestStatus.expired)),
        IncomingStanding.expired,
      );
      expect(standingOf(testIncoming(offerCount: 3)), IncomingStanding.full);
      expect(
        standingOf(testIncoming(), closedSince: true),
        IncomingStanding.closed,
      );
      expect(IncomingStanding.open.isLive, isTrue);
      expect(IncomingStanding.offerSent.isLive, isTrue);
      expect(IncomingStanding.chosen.isClosed, isFalse);
      expect(IncomingStanding.full.isClosed, isTrue);
    });

    test('in words, about the consumer', () {
      String? label(IncomingStanding standing, {Honorific? honorific}) =>
          standingLabel(
            l10n,
            testIncoming(
              myOffer: testMyOffer(),
              honorific: honorific ?? Honorific.ms,
            ),
            standing,
          );
      expect(label(IncomingStanding.open), isNull);
      expect(label(IncomingStanding.offerSent), 'بعتّ عرضك · 350 ج.م');
      expect(label(IncomingStanding.chosen), 'اختارت عرضك');
      expect(
        label(IncomingStanding.chosen, honorific: Honorific.mr),
        'اختار عرضك',
      );
      expect(label(IncomingStanding.notChosen), 'اختارت فني تاني');
      expect(label(IncomingStanding.cancelled), 'العميلة لغت الطلب');
      expect(
        label(IncomingStanding.cancelled, honorific: Honorific.mr),
        'العميل لغى الطلب',
      );
      expect(label(IncomingStanding.expired), l10n.incomingClosedExpired);
      expect(label(IncomingStanding.full), l10n.incomingClosedFull);
      expect(label(IncomingStanding.closed), l10n.incomingClosed);
    });
  });
}
