import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/done_view.dart';

import '../../../../../helpers/follow_up_harness.dart';
import '../../../../../helpers/marketplace_fixtures.dart';
import '../../../../../pump_app.dart';

void main() {
  late FollowUpHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
    registerFallbackValue(
      const ReviewDraft(stars: 5, paidWith: ConsumerPayment.cash),
    );
  });

  setUp(() => harness = FollowUpHarness());

  const lines = [
    PriceLine(
      title: 'كشف وتنظيف',
      unitPricePiastres: 35000,
      quantity: 1,
      addedLater: false,
    ),
    PriceLine(
      title: 'شحن فريون جزئي',
      unitPricePiastres: 30000,
      quantity: 1,
      addedLater: true,
    ),
  ];

  RequestDetails finished({
    QuoteStatus quoteStatus = QuoteStatus.accepted,
    List<PriceLine> items = lines,
    SubmittedReview? review,
    bool hasOpenComplaint = false,
  }) => testRequestDetails(
    job: testRequestJob(
      status: JobStatus.finished,
      quoteStatus: quoteStatus,
      quoteSentAt: DateTime(2026, 10, 3, 12, 35),
      items: items,
    ),
    review: review,
    hasOpenComplaint: hasOpenComplaint,
  );

  final review = SubmittedReview(
    stars: 4,
    paidWith: ConsumerPayment.instapay,
    createdAt: DateTime(2026, 10, 3, 15),
    tags: const {ReviewTag.onTime, ReviewTag.respectful},
    comment: 'شغل نضيف',
  );

  Future<void> pump(
    WidgetTester tester,
    RequestDetails details, {
    RequestAction? busy,
    List<String> stubRoutes = const [],
  }) {
    when(() => harness.request.state).thenReturn(
      RequestState(
        status: RequestLoadStatus.ready,
        details: details,
        busy: busy,
      ),
    );
    return harness.pump(
      tester,
      DoneView(details: details),
      stubRoutes: stubRoutes,
    );
  }

  Finder submit() => find.widgetWithText(FilledButton, l10n.doneSubmit('ms'));

  group('the invoice', () {
    testWidgets('lists the lines, the total and what was added', (
      tester,
    ) async {
      await pump(tester, finished());

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.doneTitle), findsOneWidget);
      expect(find.text(l10n.doneInvoiceFrom('محمود السيد')), findsOneWidget);
      expect(find.text('السبت 2:10 الضهر'), findsOneWidget);
      expect(find.text('كشف وتنظيف'), findsOneWidget);
      expect(find.text('شحن فريون جزئي'), findsOneWidget);
      expect(find.text(l10n.pounds('650')), findsOneWidget);
      expect(
        find.text(l10n.doneAddedApproved('ms', 1, 'شحن فريون جزئي')),
        findsOneWidget,
      );
    });

    testWidgets('says when the added lines were declined', (tester) async {
      await pump(tester, finished(quoteStatus: QuoteStatus.declined));

      expect(
        find.text(l10n.doneAddedDeclined('ms', 1, 'شحن فريون جزئي')),
        findsOneWidget,
      );
    });

    testWidgets('has no note without added lines', (tester) async {
      await pump(tester, finished(items: [lines.first]));

      expect(find.textContaining('اتضاف'), findsNothing);
      expect(find.text(l10n.pounds('350')), findsOneWidget);
    });
  });

  group('rating', () {
    testWidgets('sends nothing until the stars and the payment are picked', (
      tester,
    ) async {
      await pump(tester, finished());

      expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
      await tester.tap(find.text(l10n.donePaidCash));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
    });

    testWidgets('names each star count', (tester) async {
      await pump(tester, finished());

      for (final (stars, word) in [
        (1, l10n.doneRatingAwful),
        (2, l10n.doneRatingMeh),
        (3, l10n.doneRatingGood),
        (4, l10n.doneRatingVeryGood),
        (5, l10n.doneRatingExcellent),
      ]) {
        await tester.tap(find.byTooltip(l10n.doneStars(stars)));
        await tester.pump();
        expect(find.text(word), findsOneWidget);
      }
    });

    testWidgets('sends the stars, payment, chips and comment', (tester) async {
      when(
        () => harness.request.submitReview(any()),
      ).thenAnswer((_) async => true);
      await pump(tester, finished());

      await tester.tap(find.text(l10n.donePaidInstapay));
      await tester.tap(find.byTooltip(l10n.doneStars(4)));
      await tester.pump();
      await reveal(tester, find.text(l10n.doneTagRespectful));
      await tester.tap(find.text(l10n.doneTagOnTime));
      await tester.tap(find.text(l10n.doneTagRespectful));
      await tester.tap(find.text(l10n.doneTagCleanWork));
      await tester.pump();
      await tester.tap(find.text(l10n.doneTagCleanWork));
      await reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), '  شغل   نضيف ');
      await tester.pump();
      await tester.tap(submit());
      await tester.pump();

      verify(
        () => harness.request.submitReview(
          const ReviewDraft(
            stars: 4,
            paidWith: ConsumerPayment.instapay,
            tags: {ReviewTag.onTime, ReviewTag.respectful},
            comment: 'شغل نضيف',
          ),
        ),
      ).called(1);
    });

    testWidgets('shows the rating being sent', (tester) async {
      await pump(tester, finished(), busy: RequestAction.review);

      expect(find.text(l10n.doneSubmit('ms')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('speaks to a man as a man', (tester) async {
      harness = FollowUpHarness(honorific: Honorific.mr);
      await pump(tester, finished());

      expect(find.text(l10n.donePaidQuestion('mr')), findsOneWidget);
      expect(find.text(l10n.doneSubmit('mr')), findsOneWidget);
      expect(
        find.text(l10n.doneAddedApproved('mr', 1, 'شحن فريون جزئي')),
        findsOneWidget,
      );
    });
  });

  group('once rated', () {
    testWidgets('shows the rating and thanks', (tester) async {
      await pump(tester, finished(review: review));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.doneSubmit('ms')), findsNothing);
      await reveal(tester, find.text(l10n.doneThanks));
      expect(find.text(l10n.doneThanksBody('ms', 'محمود')), findsOneWidget);
      await reveal(tester, find.text(l10n.doneRatingVeryGood));
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == l10n.doneStars(4),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.doneTagOnTime), findsOneWidget);
      expect(find.text(l10n.doneTagRespectful), findsOneWidget);
      expect(find.text(l10n.doneTagCleanWork), findsNothing);
      expect(find.text('شغل نضيف'), findsOneWidget);
    });

    testWidgets('goes back home', (tester) async {
      await pump(
        tester,
        finished(review: review),
        stubRoutes: [AppRoutes.consumerHome],
      );

      await tester.tap(find.text(l10n.doneBackHome));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerHome), findsOneWidget);
    });

    testWidgets('opens a complaint and says it was sent', (tester) async {
      final complaint = AppRoutes.requestComplaint('request-1');
      await pump(tester, finished(review: review), stubRoutes: [complaint]);

      await reveal(tester, find.text(l10n.complaintTitle));
      await tester.tap(find.text(l10n.complaintTitle));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop(true);
      await tester.pumpAndSettle();

      expect(find.text(l10n.complaintSent), findsOneWidget);
      verify(harness.request.refresh).called(1);
    });

    testWidgets('says a complaint is open instead', (tester) async {
      await pump(tester, finished(review: review, hasOpenComplaint: true));

      await reveal(tester, find.text(l10n.complaintOpen));
      expect(find.text(l10n.complaintTitle), findsNothing);
    });
  });
}
