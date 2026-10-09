import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/closed_request_view.dart';

import '../../../../../helpers/request_views_fixtures.dart';
import '../../../../../helpers/request_views_harness.dart';
import '../../../../../pump_app.dart';

void main() {
  late ConsumerViewHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() => harness = ConsumerViewHarness());

  Future<void> pumpView(WidgetTester tester, RequestDetails details) =>
      harness.pump(
        tester,
        ClosedRequestView(details: details),
        stubRoutes: [AppRoutes.newRequest],
      );

  testWidgets('she cancelled before picking: the use came back', (
    tester,
  ) async {
    final details = liveRequest(
      status: RequestStatus.cancelled,
      cancelledBy: UserRole.consumer,
    );

    await pumpView(tester, details);

    expect(tester.takeException(), isNull);
    expect(find.text('تكييف مش بيبرّد'), findsOneWidget);
    expect(find.text('لغيتي الطلب ده'), findsOneWidget);
    expect(find.text(l10n.closedRequestFreeCancel), findsOneWidget);
    expect(
      find.text('${weekdayDate(details.day)} · الضهر 12 لـ 3'),
      findsOneWidget,
    );
    expect(find.text('البيت · مدينة نصر'), findsOneWidget);
    expect(find.text('اطلبي تاني'), findsOneWidget);
  });

  testWidgets('she cancelled after picking: the technician was told', (
    tester,
  ) async {
    await pumpView(
      tester,
      liveRequest(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.consumer,
        offers: liveOffers(),
        chosenOfferId: 'offer-2',
      ),
    );

    expect(find.text(l10n.closedRequestTechnicianTold), findsOneWidget);
    expect(find.text(l10n.closedRequestFreeCancel), findsNothing);
  });

  testWidgets('the technician cancelled', (tester) async {
    await pumpView(
      tester,
      liveRequest(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.technician,
        offers: liveOffers(),
        chosenOfferId: 'offer-2',
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('الفني لغى، ورصيدك رجعلك'), findsOneWidget);
    expect(find.text(l10n.closedRequestAskOthers('ms')), findsOneWidget);
  });

  testWidgets('nobody sent an offer in time', (tester) async {
    await pumpView(
      tester,
      liveRequest(status: RequestStatus.expired, day: dayFromToday(-1)),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('محدش بعت عرض في الوقت ده، ورصيدك رجعلك'),
      findsOneWidget,
    );
    expect(find.text(l10n.closedRequestTryAnotherTime('ms')), findsOneWidget);
  });

  testWidgets('its time passed without a pick', (tester) async {
    await pumpView(
      tester,
      liveRequest(status: RequestStatus.expired, offers: liveOffers()),
    );

    expect(
      find.text('معاد الطلب فات من غير ما تختاري فني، ورصيدك رجعلك'),
      findsOneWidget,
    );
  });

  testWidgets('speaks to a man in his words', (tester) async {
    harness = ConsumerViewHarness(honorific: Honorific.mr);

    await pumpView(
      tester,
      liveRequest(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.consumer,
      ),
    );

    expect(find.text('لغيت الطلب ده'), findsOneWidget);
    expect(find.text('اطلب تاني'), findsOneWidget);
  });

  testWidgets('asks again for the same kind of work', (tester) async {
    await pumpView(tester, liveRequest(status: RequestStatus.expired));

    await tester.tap(find.text('اطلبي تاني'));
    await tester.pumpAndSettle();

    final page = tester.element(find.text(AppRoutes.newRequest));
    expect(
      GoRouterState.of(page).uri.toString(),
      AppRoutes.newRequestFor(categoryId: 'ac'),
    );
  });
}
