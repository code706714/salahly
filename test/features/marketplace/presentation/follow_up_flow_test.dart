import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/closed_request_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/done_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/price_change_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/track_view.dart';

import '../../../helpers/consumer_app.dart';
import '../../../helpers/follow_up_harness.dart';
import '../../../helpers/marketplace_fixtures.dart';
import '../../../pump_app.dart';

// The consumer's follow-up through the whole app: tracking, a new price,
// rating, complaints and "طلباتي".
void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
    registerFallbackValue(
      const ReviewDraft(stars: 5, paidWith: ConsumerPayment.cash),
    );
    registerFallbackValue(const ComplaintDraft(reason: ComplaintReason.other));
  });

  void serve(ConsumerApp app, RequestDetails details) => when(
    () => app.requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => Ok(details));

  Future<void> open(WidgetTester tester, ConsumerApp app) =>
      app.pump(tester, location: AppRoutes.request('request-1'));

  testConsumerApp('cancels a picked technician', (tester, app) async {
    serve(app, testRequestDetails(job: testRequestJob()));
    when(
      () => app.requests.cancelRequest('request-1'),
    ).thenAnswer((_) async {
      serve(
        app,
        testRequestDetails(
          status: RequestStatus.cancelled,
          cancelledBy: UserRole.consumer,
        ),
      );
      return const Ok(null);
    });
    await open(tester, app);
    expect(find.byType(TrackView), findsOneWidget);

    await reveal(tester, find.text(l10n.trackCancel));
    await tester.tap(find.text(l10n.trackCancel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.trackCancel).last);
    await app.settle(tester);

    verify(() => app.requests.cancelRequest('request-1')).called(1);
    expect(find.byType(ClosedRequestView), findsOneWidget);
  });

  testConsumerApp('approves a new price and follows the work at it', (
    tester,
    app,
  ) async {
    final change = testPriceChangeJob();
    serve(app, testRequestDetails(job: change));
    when(
      () => app.requests.answerPriceChange(
        'request-1',
        quoteSentAt: any(named: 'quoteSentAt'),
        approve: any(named: 'approve'),
      ),
    ).thenAnswer((_) async {
      serve(
        app,
        testRequestDetails(
          job: testRequestJob(
            status: JobStatus.started,
            quoteSentAt: change.quoteSentAt,
            items: change.items,
          ),
        ),
      );
      return const Ok(null);
    });
    await open(tester, app);
    expect(find.byType(PriceChangeView), findsOneWidget);

    await tester.tap(find.text(l10n.priceChangeApprove('650')));
    await app.settle(tester);

    verify(
      () => app.requests.answerPriceChange(
        'request-1',
        quoteSentAt: change.quoteSentAt!,
        approve: true,
      ),
    ).called(1);
    expect(find.byType(TrackView), findsOneWidget);
    expect(
      find.text(l10n.priceChangeApproved('ms', '650', 'محمود')),
      findsOneWidget,
    );
    await reveal(tester, find.text(l10n.trackPriceAgreed));
    expect(find.text(l10n.pounds('650')), findsOneWidget);
  });

  testConsumerApp('rates the finished work', (tester, app) async {
    final job = testRequestJob(status: JobStatus.finished);
    serve(app, testRequestDetails(job: job));
    when(() => app.requests.submitReview('request-1', any())).thenAnswer((
      _,
    ) async {
      serve(
        app,
        testRequestDetails(
          job: job,
          review: SubmittedReview(
            stars: 5,
            paidWith: ConsumerPayment.cash,
            createdAt: DateTime(2026, 10, 3, 15),
            tags: const {ReviewTag.onTime},
          ),
        ),
      );
      return const Ok(null);
    });
    await open(tester, app);
    expect(find.byType(DoneView), findsOneWidget);

    await tester.tap(find.text(l10n.donePaidCash));
    await tester.tap(find.byTooltip(l10n.doneStars(5)));
    await tester.pump();
    await reveal(tester, find.text(l10n.doneTagOnTime));
    await tester.tap(find.text(l10n.doneTagOnTime));
    await tester.pump();
    await tester.tap(find.text(l10n.doneSubmit('ms')));
    await app.settle(tester);

    verify(
      () => app.requests.submitReview(
        'request-1',
        const ReviewDraft(
          stars: 5,
          paidWith: ConsumerPayment.cash,
          tags: {ReviewTag.onTime},
        ),
      ),
    ).called(1);
    await reveal(tester, find.text(l10n.doneThanks));
    expect(find.text(l10n.doneSubmit('ms')), findsNothing);
  });

  testConsumerApp('reports a problem and comes back to the request', (
    tester,
    app,
  ) async {
    final details = testRequestDetails(
      job: testRequestJob(status: JobStatus.started),
    );
    serve(app, details);
    when(
      () => app.requests.submitComplaint('request-1', any()),
    ).thenAnswer((_) async {
      serve(
        app,
        testRequestDetails(
          job: testRequestJob(status: JobStatus.started),
          hasOpenComplaint: true,
        ),
      );
      return const Ok(null);
    });
    await open(tester, app);

    await reveal(tester, find.text(l10n.complaintTitle));
    await tester.tap(find.text(l10n.complaintTitle));
    await app.settle(tester);
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.complaintSubtitle('تكييف مش بيبرّد', 'محمود السيد')),
      findsOneWidget,
    );
    await tester.tap(find.text(l10n.complaintReasonPoorWork));
    await tester.pump();
    await reveal(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'التكييف لسه مش بيبرّد');
    await tester.tap(find.text(l10n.complaintSubmit('ms')));
    await app.settle(tester);
    await tester.pumpAndSettle();

    verify(
      () => app.requests.submitComplaint(
        'request-1',
        const ComplaintDraft(
          reason: ComplaintReason.poorWork,
          details: 'التكييف لسه مش بيبرّد',
        ),
      ),
    ).called(1);
    expect(find.byType(TrackView), findsOneWidget);
    expect(find.text(l10n.complaintSent), findsOneWidget);
    await reveal(tester, find.text(l10n.complaintOpen));
  });

  group('طلباتي', () {
    testConsumerApp('opens a request from the list', (tester, app) async {
      when(app.requests.fetchRequests).thenAnswer(
        (_) async => Ok([
          testRequestSummary(
            status: RequestStatus.assigned,
            jobStatus: JobStatus.confirmed,
            technicianName: 'محمود السيد',
          ),
        ]),
      );
      serve(app, testRequestDetails(job: testRequestJob()));
      await app.pump(tester, location: AppRoutes.consumerRequests);
      expect(find.text(l10n.myRequestsActive), findsOneWidget);

      await tester.tap(find.text('تكييف مش بيبرّد'));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TrackView), findsOneWidget);
    });

    testConsumerApp('asks a past technician again', (tester, app) async {
      when(app.requests.fetchRequests).thenAnswer(
        (_) async => Ok([
          testRequestSummary(
            status: RequestStatus.assigned,
            jobStatus: JobStatus.paid,
            technicianName: 'ياسر عبد الحميد',
            reviewStars: 5,
          ),
        ]),
      );
      when(
        () => app.requests.fetchListedTechnician('tech-1'),
      ).thenAnswer((_) async => Ok(testTechnicianProfile()));
      await app.pump(tester, location: AppRoutes.consumerRequests);

      await tester.tap(find.text(l10n.myRequestsAgain('ms', 'ياسر')));
      await app.settle(tester);
      await tester.pumpAndSettle();

      final page = tester.widget<NewRequestPage>(find.byType(NewRequestPage));
      expect(page.categoryId, 'ac');
      expect(page.technicianId, 'tech-1');
    });

    testConsumerApp('fetches the list again when pulled down', (
      tester,
      app,
    ) async {
      when(app.requests.fetchRequests).thenAnswer(
        (_) async => Ok([testRequestSummary(status: RequestStatus.expired)]),
      );
      await app.pump(tester, location: AppRoutes.consumerRequests);
      clearInteractions(app.requests);
      when(app.requests.fetchRequests).thenAnswer(
        (_) async => Ok([
          testRequestSummary(status: RequestStatus.expired),
          testRequestSummary(id: 'request-2', offerCount: 2),
        ]),
      );

      await tester.fling(
        find.text(l10n.myRequestsExpired),
        const Offset(0, 400),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await app.settle(tester);
      await tester.pumpAndSettle();

      verify(app.requests.fetchRequests).called(1);
      expect(find.text(l10n.myRequestsOffers(2)), findsOneWidget);
    });
  });
}
