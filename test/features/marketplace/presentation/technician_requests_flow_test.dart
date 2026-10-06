import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/incoming_request_details.dart';

import '../../../helpers/incoming_fixtures.dart';
import '../../../helpers/job_seed.dart';
import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
    registerFallbackValue(
      OfferDraft(pricePiastres: 100, arriveAt: DateTime(2026)),
    );
  });

  /// A request sent 20 minutes ago for tomorrow noon.
  IncomingRequest recent({MyOffer? myOffer, bool dismissed = false}) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return testIncoming(
      createdAt: now.subtract(const Duration(minutes: 20)),
      day: tomorrow,
      expiresAt: tomorrow.add(const Duration(hours: 15)),
      myOffer: myOffer,
      dismissed: dismissed,
    );
  }

  void serveList(TechnicianApp app, List<IncomingRequest> requests) => when(
    app.requests.fetchNewRequests,
  ).thenAnswer((_) async => Ok(requests));

  void serveRequest(TechnicianApp app, IncomingRequest request) => when(
    () => app.requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => Ok(request));

  Future<void> openRequestFromToday(
    WidgetTester tester,
    TechnicianApp app,
  ) async {
    await tester.tap(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')));
    await app.settle(tester);
    await tester.tap(find.text('تكييف مش بيبرّد'));
    await app.settle(tester);
    // Lets the page finish sliding in.
    await tester.pump(const Duration(seconds: 1));
  }

  testTechnicianApp('sends an offer on a new request from today', (
    tester,
    app,
  ) async {
    final request = recent();
    serveList(app, [request]);
    serveRequest(app, request);
    when(app.requests.fetchMyServices).thenAnswer(
      (_) async => const Ok([
        ServicePrice(
          serviceId: 'ac_inspection_cleaning',
          startingPricePiastres: 35000,
        ),
      ]),
    );
    final tomorrowNoon = request.day.add(const Duration(hours: 12));
    final sent = recent(
      myOffer: MyOffer(
        id: 'offer-1',
        serviceId: 'ac_inspection_cleaning',
        pricePiastres: 35000,
        arriveAt: tomorrowNoon,
        status: OfferStatus.sent,
      ),
    );
    when(() => app.requests.sendOffer('request-1', any())).thenAnswer((
      _,
    ) async {
      serveRequest(app, sent);
      serveList(app, const []);
      return const Ok('offer-1');
    });
    await app.pump(tester);

    expect(find.text(l10n.todayRequestsCreditsLeft(2)), findsOneWidget);
    await openRequestFromToday(tester, app);
    verify(() => app.requests.fetchRequest('request-1')).called(1);

    // Brings the price chips clear of the buttons at the bottom.
    await tester.drag(
      find.byType(IncomingRequestDetails),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('كشف وتنظيف 350'));
    await tester.pump();
    await tester.tap(find.text(l10n.offerFormSend('350')));
    await app.settle(tester);

    verify(
      () => app.requests.sendOffer(
        'request-1',
        OfferDraft(
          serviceId: 'ac_inspection_cleaning',
          pricePiastres: 35000,
          arriveAt: tomorrowNoon,
        ),
      ),
    ).called(1);
    expect(find.text(l10n.offerFormWaiting('ms')), findsOneWidget);
    expect(find.text(l10n.offerFormDismiss), findsNothing);

    await tester.tap(find.byTooltip(l10n.back));
    await app.settle(tester);
    expect(find.text('بعتّ عرضك · 350 ج.م'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.back));
    await app.settle(tester);
    expect(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')), findsNothing);
  });

  testTechnicianApp('a request that is not for me leaves the list', (
    tester,
    app,
  ) async {
    final request = recent();
    serveList(app, [request]);
    serveRequest(app, request);
    when(() => app.requests.dismissRequest('request-1')).thenAnswer((
      _,
    ) async {
      serveRequest(app, recent(dismissed: true));
      serveList(app, const []);
      return const Ok(null);
    });
    await app.pump(tester);
    await openRequestFromToday(tester, app);

    await tester.tap(find.text(l10n.offerFormDismiss));
    await app.settle(tester);
    await tester.tap(find.text(l10n.offerFormDismissConfirm));
    await app.settle(tester);

    verify(() => app.requests.dismissRequest('request-1')).called(1);
    expect(find.text(l10n.incomingEmpty), findsOneWidget);
  });

  group('a job from the platform', () {
    /// Seeds before the app opens, while nothing else uses the database.
    Future<String> seedPlatformJob(
      WidgetTester tester,
      TechnicianApp app,
    ) async {
      final id = await tester.runAsync(() async {
        final customerId = await seedCustomer(
          app,
          'نورهان محمد',
          phone: '01002345678',
        );
        final id = await seedJob(
          app,
          customerId,
          tags: const [JobTag.notCooling],
          at: DateTime.now().add(const Duration(days: 1)),
        );
        await app.jobs.saveQuote(
          id,
          items: const [
            JobItemDraft(title: 'كشف وتنظيف', unitPricePiastres: 35000),
            JobItemDraft(title: 'شحن فريون', unitPricePiastres: 30000),
          ],
          validDays: Job.defaultQuoteValidDays,
          status: QuoteStatus.draft,
        );
        await (app.database.update(
          app.database.jobs,
        )..where((job) => job.id.equals(id))).write(
          const JobsCompanion(source: Value('platform')),
        );
        return id;
      });
      return id!;
    }

    testTechnicianApp('sends a price change to the consumer in the app', (
      tester,
      app,
    ) async {
      final id = await seedPlatformJob(tester, app);
      await app.pump(tester);
      unawaited(app.router(tester).push(AppRoutes.job(id)));
      await app.settle(tester);

      expect(find.text(l10n.jobFromPlatform), findsOneWidget);
      await tester.drag(
        find.text(l10n.jobFromPlatform),
        const Offset(0, -400),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text(l10n.jobPageQuoteDraft));
      await app.settle(tester);

      expect(find.text(l10n.platformJobQuoteInApp), findsOneWidget);
      await tester.tap(find.text(l10n.platformJobQuoteSend));
      await app.settle(tester);

      verifyNever(
        () => app.apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      );
      final job = (await tester.runAsync(
        () => app.jobs.watchJob(id).first,
      ))!.job;
      expect(job.quoteStatus, QuoteStatus.sent);
      expect(find.text(l10n.jobQuoteSent), findsWidgets);
    });

    testTechnicianApp('is cancelled for good and never deleted', (
      tester,
      app,
    ) async {
      final id = await seedPlatformJob(tester, app);
      await app.pump(tester);
      unawaited(app.router(tester).push(AppRoutes.job(id)));
      await app.settle(tester);

      await tester.tap(find.byTooltip(l10n.jobPageMore));
      await app.settle(tester);
      expect(find.text(l10n.jobPageDelete), findsNothing);
      await tester.tap(find.text(l10n.jobPageCancel));
      await app.settle(tester);
      await tester.tap(find.text(l10n.platformJobCancelConfirm));
      await app.settle(tester);

      final job = (await tester.runAsync(
        () => app.jobs.watchJob(id).first,
      ))!.job;
      expect(job.status, JobStatus.cancelled);
      expect(find.text(l10n.jobPageUndo), findsNothing);
      expect(find.byTooltip(l10n.jobPageMore), findsNothing);
    });
  });
}
