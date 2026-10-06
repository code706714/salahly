import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/my_requests_page.dart';

import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late FollowUpHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
  });

  setUp(() => harness = FollowUpHarness());

  Future<void> pump(
    WidgetTester tester,
    MyRequestsState state, {
    List<String> stubRoutes = const [],
  }) {
    when(() => harness.requests.state).thenReturn(state);
    return harness.pump(
      tester,
      const MyRequestsView(),
      stubRoutes: stubRoutes,
    );
  }

  MyRequestsState ready(List<RequestSummary> requests) =>
      MyRequestsState(status: MyRequestsStatus.ready, requests: requests);

  /// Sent [ago], with no technician yet.
  RequestSummary sent(
    Duration ago, {
    String id = 'request-9',
    int offerCount = 0,
  }) {
    final now = DateTime.now();
    return RequestSummary(
      id: id,
      categoryId: 'ac',
      issue: RequestIssue.needsCleaning,
      status: RequestStatus.open,
      day: DateTime(now.year, now.month, now.day),
      window: RequestWindow.noon,
      createdAt: now.subtract(ago),
      offerCount: offerCount,
    );
  }

  final confirmed = testRequestSummary(
    status: RequestStatus.assigned,
    jobStatus: JobStatus.confirmed,
    technicianName: 'محمود السيد',
  );
  final rated = testRequestSummary(
    id: 'request-3',
    status: RequestStatus.assigned,
    jobStatus: JobStatus.paid,
    technicianName: 'ياسر عبد الحميد',
    reviewStars: 5,
  );
  final cancelled = testRequestSummary(
    id: 'request-4',
    issue: RequestIssue.leaking,
    status: RequestStatus.cancelled,
    cancelledBy: UserRole.consumer,
  );

  testWidgets('shows the active requests, then the past ones', (
    tester,
  ) async {
    await pump(
      tester,
      ready([confirmed, sent(const Duration(minutes: 40)), rated, cancelled]),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.navMyRequests), findsOneWidget);
    final active = tester.getTopLeft(find.text(l10n.myRequestsActive)).dy;
    final past = tester.getTopLeft(find.text(l10n.myRequestsPast)).dy;
    expect(active, lessThan(past));
    expect(
      tester.getTopLeft(find.text('تنظيف تكييف')).dy,
      allOf(greaterThan(active), lessThan(past)),
    );
    expect(
      find.text('السبت 12:00 الضهر · محمود السيد · ${l10n.pounds('350')}'),
      findsOneWidget,
    );
    expect(
      find.text(
        '${l10n.myRequestsSentMinutes(40)} · ${l10n.myRequestsNoOffers}',
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.myRequestsWaiting), findsOneWidget);
    expect(find.text(l10n.myRequestsRated(5)), findsOneWidget);
    expect(
      find.text('3 أكتوبر · ياسر عبد الحميد · ${l10n.pounds('350')}'),
      findsOneWidget,
    );
    await reveal(tester, find.text(l10n.myRequestsCancelledByYou('ms')));
    expect(
      find.text('3 أكتوبر · ${l10n.myRequestsBeforePick('ms')}'),
      findsOneWidget,
    );
  });

  testWidgets('shows only the sections that have requests', (tester) async {
    await pump(tester, ready([rated]));

    expect(find.text(l10n.myRequestsActive), findsNothing);
    expect(find.text(l10n.myRequestsPast), findsOneWidget);
  });

  testWidgets('highlights a confirmed or started job', (tester) async {
    await pump(tester, ready([confirmed, sent(const Duration(minutes: 5))]));

    final cards = tester.widgetList<AppCard>(find.byType(AppCard)).toList();
    expect(cards.first.borderWidth, 2);
    expect(cards.last.borderWidth, 1.5);
  });

  group('says where each request stands', () {
    for (final (name, request, pill) in [
      ('no offers', sent(const Duration(minutes: 1)), l10n.myRequestsWaiting),
      (
        'offers',
        sent(const Duration(minutes: 1), offerCount: 2),
        l10n.myRequestsOffers(2),
      ),
      (
        'picked',
        testRequestSummary(
          status: RequestStatus.assigned,
          jobStatus: JobStatus.unconfirmed,
          technicianName: 'محمود السيد',
        ),
        l10n.myRequestsChosen('محمود'),
      ),
      (
        'working',
        testRequestSummary(
          status: RequestStatus.assigned,
          jobStatus: JobStatus.started,
          technicianName: 'محمود السيد',
        ),
        l10n.myRequestsWorking('محمود'),
      ),
      (
        'finished, not rated',
        testRequestSummary(
          status: RequestStatus.assigned,
          jobStatus: JobStatus.finished,
          technicianName: 'محمود السيد',
        ),
        l10n.myRequestsRate('ms'),
      ),
      (
        'cancelled by the technician',
        testRequestSummary(
          status: RequestStatus.cancelled,
          cancelledBy: UserRole.technician,
        ),
        l10n.myRequestsCancelledByTechnician,
      ),
      (
        'the job called off',
        testRequestSummary(
          status: RequestStatus.assigned,
          jobStatus: JobStatus.cancelled,
          technicianName: 'محمود السيد',
        ),
        l10n.myRequestsCancelledByTechnician,
      ),
      (
        'expired',
        testRequestSummary(status: RequestStatus.expired),
        l10n.myRequestsExpired,
      ),
    ]) {
      testWidgets(name, (tester) async {
        await pump(tester, ready([request]));

        expect(tester.takeException(), isNull);
        expect(find.text(pill), findsOneWidget);
      });
    }
  });

  testWidgets('says when an expired request got no offers', (tester) async {
    await pump(
      tester,
      ready([testRequestSummary(status: RequestStatus.expired)]),
    );

    expect(
      find.text('3 أكتوبر · ${l10n.myRequestsNoOffersCame}'),
      findsOneWidget,
    );
  });

  testWidgets('names the day the technician is coming', (tester) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 12);
    await pump(
      tester,
      ready([
        RequestSummary(
          id: 'request-1',
          categoryId: 'ac',
          issue: RequestIssue.notCooling,
          status: RequestStatus.assigned,
          day: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
          window: RequestWindow.noon,
          createdAt: now,
          offerCount: 1,
          technicianId: 'tech-1',
          technicianName: 'محمود السيد',
          pricePiastres: 35000,
          jobStatus: JobStatus.confirmed,
          scheduledAt: tomorrow,
        ),
      ]),
    );

    expect(
      find.text(l10n.myRequestsComing('محمود', l10n.tomorrow)),
      findsOneWidget,
    );
  });

  group('how long ago it was sent', () {
    for (final (ago, label) in [
      (Duration.zero, l10n.myRequestsSentMinutes(0)),
      (const Duration(hours: 3), l10n.myRequestsSentHours(3)),
      (const Duration(days: 2, hours: 1), l10n.myRequestsSentDays(2)),
    ]) {
      testWidgets(label, (tester) async {
        await pump(tester, ready([sent(ago, offerCount: 1)]));

        expect(find.text(label), findsOneWidget);
      });
    }
  });

  testWidgets('opens a request', (tester) async {
    final route = AppRoutes.request('request-1');
    await pump(tester, ready([confirmed]), stubRoutes: [route]);

    await tester.tap(find.text('تكييف مش بيبرّد'));
    await tester.pumpAndSettle();

    expect(find.text(route), findsOneWidget);
  });

  testWidgets('asks the same technician again', (tester) async {
    await pump(
      tester,
      ready([rated]),
      stubRoutes: [AppRoutes.newRequestFor()],
    );

    await tester.tap(find.text(l10n.myRequestsAgain('ms', 'ياسر')));
    await tester.pumpAndSettle();

    final opened = GoRouterState.of(
      tester.element(find.text(AppRoutes.newRequestFor())),
    );
    expect(
      opened.uri.toString(),
      AppRoutes.newRequestFor(categoryId: 'ac', technicianId: 'tech-1'),
    );
  });

  testWidgets('refreshes when pulled down', (tester) async {
    await pump(tester, ready([confirmed]));

    await tester.fling(
      find.text('تكييف مش بيبرّد'),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    verify(harness.requests.load).called(1);
  });

  testWidgets('says when a refresh failed and keeps the list', (
    tester,
  ) async {
    final shown = ready([confirmed]);
    whenListen(
      harness.requests,
      Stream.value(
        MyRequestsState(
          status: MyRequestsStatus.ready,
          requests: shown.requests,
          failure: const NetworkFailure(),
        ),
      ),
      initialState: shown,
    );
    await harness.pump(tester, const MyRequestsView());
    await tester.pump();

    expect(find.text(l10n.consumerErrorNetwork('ms')), findsOneWidget);
    expect(find.text('تكييف مش بيبرّد'), findsOneWidget);
  });

  testWidgets('shows a spinner while loading', (tester) async {
    await pump(tester, const MyRequestsState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('retries a list that could not be fetched', (tester) async {
    await pump(
      tester,
      const MyRequestsState(
        status: MyRequestsStatus.failed,
        failure: NetworkFailure(),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.myRequestsLoadFailed), findsOneWidget);
    expect(find.text(l10n.consumerErrorNetwork('ms')), findsOneWidget);
    await tester.tap(find.text(l10n.consumerRetry('ms')));

    verify(harness.requests.load).called(1);
  });

  testWidgets('invites a consumer with no requests to ask for one', (
    tester,
  ) async {
    await pump(tester, ready(const []), stubRoutes: [AppRoutes.consumerHome]);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.myRequestsEmpty('ms')), findsOneWidget);
    expect(find.text(l10n.myRequestsEmptyBody('ms')), findsOneWidget);
    await tester.tap(find.text(l10n.myRequestsEmptyAction('ms')));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.consumerHome), findsOneWidget);
  });

  testWidgets('speaks to a man as a man', (tester) async {
    harness = FollowUpHarness(honorific: Honorific.mr);
    await pump(tester, ready([rated, cancelled]));

    expect(find.text(l10n.myRequestsAgain('mr', 'ياسر')), findsOneWidget);
    expect(find.text(l10n.myRequestsCancelledByYou('mr')), findsOneWidget);
  });
}
