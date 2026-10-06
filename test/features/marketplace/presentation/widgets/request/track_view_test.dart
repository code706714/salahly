import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/track_view.dart';

import '../../../../../helpers/follow_up_harness.dart';
import '../../../../../helpers/marketplace_fixtures.dart';
import '../../../../../pump_app.dart';

void main() {
  late FollowUpHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
  });

  setUp(() => harness = FollowUpHarness());

  final phone = PhoneNumber.tryParse('+201009990041')!;

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
      TrackView(details: details),
      stubRoutes: stubRoutes,
    );
  }

  RequestDetails at(JobStatus status, {bool hasOpenComplaint = false}) =>
      testRequestDetails(
        job: testRequestJob(status: status),
        hasOpenComplaint: hasOpenComplaint,
      );

  group('by stage', () {
    testWidgets('waits for the technician to confirm', (tester) async {
      await pump(tester, at(JobStatus.unconfirmed));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.trackTitleChosen('محمود')), findsOneWidget);
      expect(find.text(l10n.trackStepSent), findsOneWidget);
      expect(
        find.text(l10n.trackStepChosen('ms', 'محمود', '350')),
        findsOneWidget,
      );
      expect(find.text(l10n.trackConfirming('محمود')), findsOneWidget);
      expect(find.text(l10n.trackStepStarted), findsOneWidget);
      expect(find.text(l10n.trackStepFinished('ms')), findsOneWidget);
      expect(find.text('الجمعة 7:40 المغرب'), findsOneWidget);
      expect(find.text('الجمعة 8:05 بالليل'), findsOneWidget);
      await reveal(tester, find.text(l10n.trackCancelNote('ms', 'محمود')));
      expect(find.text(l10n.trackCancel), findsOneWidget);
    });

    testWidgets('shows the time once confirmed', (tester) async {
      await pump(tester, at(JobStatus.confirmed));

      expect(tester.takeException(), isNull);
      // The title and the step.
      expect(find.text(l10n.trackConfirmed('محمود')), findsNWidgets(2));
      expect(find.text('السبت 12:00 الضهر'), findsOneWidget);
      await reveal(tester, find.text(l10n.trackCancel));
    });

    testWidgets('can no longer be cancelled once the work started', (
      tester,
    ) async {
      await pump(tester, at(JobStatus.started));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.trackTitleStarted('محمود')), findsOneWidget);
      expect(find.text('السبت 12:10 الضهر'), findsOneWidget);
      await reveal(tester, find.text(l10n.complaintTitle));
      expect(find.text(l10n.trackCancel), findsNothing);
      expect(find.text(l10n.trackCancelNote('ms', 'محمود')), findsNothing);
      expect(find.text(l10n.complaintTitle), findsOneWidget);
    });
  });

  testWidgets('shows the technician, the price, payment and address', (
    tester,
  ) async {
    await pump(tester, at(JobStatus.confirmed));

    expect(find.text('محمود السيد'), findsOneWidget);
    expect(find.text('4.8 · ${l10n.trackVerified('تكييف')}'), findsOneWidget);
    await reveal(tester, find.text(l10n.trackPrice));
    expect(find.text(l10n.pounds('350')), findsOneWidget);
    expect(find.text(l10n.trackPaymentValue), findsOneWidget);
    expect(find.text(testHome.details), findsOneWidget);
    expect(find.text(testHome.label), findsOneWidget);
  });

  testWidgets('shows the agreed total after an approved price change', (
    tester,
  ) async {
    final details = testRequestDetails(
      job: testRequestJob(
        status: JobStatus.started,
        quoteSentAt: DateTime(2026, 10, 3, 12, 35),
        items: const [
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
        ],
      ),
    );

    await pump(tester, details);

    await reveal(tester, find.text(l10n.trackPriceAgreed));
    expect(find.text(l10n.pounds('650')), findsOneWidget);
  });

  testWidgets('calls the technician', (tester) async {
    await pump(tester, at(JobStatus.confirmed));

    await tester.tap(find.byTooltip(l10n.trackCall('ms', 'محمود')));
    await tester.pump();

    verify(() => harness.apps.dial(phone)).called(1);
  });

  testWidgets('greets the technician on WhatsApp', (tester) async {
    await pump(tester, at(JobStatus.confirmed));

    await tester.tap(find.byTooltip(l10n.trackWhatsApp('محمود')));
    await tester.pump();

    verify(
      () => harness.apps.whatsApp(
        text: l10n.trackWhatsAppMessage(
          'ms',
          'محمود',
          'نورهان',
          'تكييف مش بيبرّد',
        ),
        to: phone,
      ),
    ).called(1);
  });

  testWidgets('greets as a man for a man', (tester) async {
    harness = FollowUpHarness(honorific: Honorific.mr);
    await pump(tester, at(JobStatus.confirmed));

    await tester.tap(find.byTooltip(l10n.trackWhatsApp('محمود')));
    await tester.pump();

    verify(
      () => harness.apps.whatsApp(
        text: l10n.trackWhatsAppMessage(
          'mr',
          'محمود',
          'نورهان',
          'تكييف مش بيبرّد',
        ),
        to: phone,
      ),
    ).called(1);
    await reveal(tester, find.text(l10n.trackCancelNote('mr', 'محمود')));
  });

  testWidgets("opens the technician's profile", (tester) async {
    final profile = AppRoutes.technicianProfile('tech-1');
    await pump(tester, at(JobStatus.confirmed), stubRoutes: [profile]);

    await tester.tap(find.text('محمود السيد'));
    await tester.pumpAndSettle();

    expect(find.text(profile), findsOneWidget);
  });

  group('cancelling', () {
    testWidgets('cancels after confirming', (tester) async {
      when(harness.request.cancel).thenAnswer((_) async => true);
      await pump(tester, at(JobStatus.confirmed));

      await reveal(tester, find.text(l10n.trackCancel));
      await tester.tap(find.text(l10n.trackCancel));
      await tester.pumpAndSettle();
      expect(find.text(l10n.trackCancelQuestion), findsOneWidget);
      await tester.tap(find.text(l10n.trackCancel).last);
      await tester.pumpAndSettle();

      verify(harness.request.cancel).called(1);
    });

    testWidgets('keeps the request when the consumer changes their mind', (
      tester,
    ) async {
      await pump(tester, at(JobStatus.unconfirmed));

      await reveal(tester, find.text(l10n.trackCancel));
      await tester.tap(find.text(l10n.trackCancel));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.trackKeep));
      await tester.pumpAndSettle();

      verifyNever(harness.request.cancel);
    });

    testWidgets('shows the cancel in progress', (tester) async {
      await pump(tester, at(JobStatus.confirmed), busy: RequestAction.cancel);

      await reveal(tester, find.text(l10n.trackCancelNote('ms', 'محمود')));
      expect(find.text(l10n.trackCancel), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('complaints', () {
    testWidgets('opens the complaint screen, then says it was sent', (
      tester,
    ) async {
      final complaint = AppRoutes.requestComplaint('request-1');
      await pump(tester, at(JobStatus.started), stubRoutes: [complaint]);

      await reveal(tester, find.text(l10n.complaintTitle));
      await tester.tap(find.text(l10n.complaintTitle));
      await tester.pumpAndSettle();
      expect(find.text(complaint), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).last).pop(true);
      await tester.pumpAndSettle();

      expect(find.text(l10n.complaintSent), findsOneWidget);
      verify(harness.request.refresh).called(1);
    });

    testWidgets('does nothing when the complaint was not sent', (
      tester,
    ) async {
      final complaint = AppRoutes.requestComplaint('request-1');
      await pump(tester, at(JobStatus.started), stubRoutes: [complaint]);

      await reveal(tester, find.text(l10n.complaintTitle));
      await tester.tap(find.text(l10n.complaintTitle));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      expect(find.text(l10n.complaintSent), findsNothing);
      verifyNever(harness.request.refresh);
    });

    testWidgets('says a complaint is open instead', (tester) async {
      await pump(tester, at(JobStatus.confirmed, hasOpenComplaint: true));

      expect(tester.takeException(), isNull);
      await reveal(tester, find.text(l10n.complaintOpen));
      expect(find.text(l10n.complaintTitle), findsNothing);
      expect(find.text(l10n.trackCancel), findsOneWidget);
    });
  });
}
