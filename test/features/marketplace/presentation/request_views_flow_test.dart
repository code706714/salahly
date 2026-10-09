import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_profile_page.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/closed_request_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/offers_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/track_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/waiting_view.dart';

import '../../../helpers/consumer_app.dart';
import '../../../helpers/marketplace_fixtures.dart';
import '../../../helpers/request_views_fixtures.dart';
import '../../../pump_app.dart';

// The waiting, offers, closed and technician screens, driven through the
// whole app.
void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    ConsumerApp.registerFallbacks();
  });

  void serve(ConsumerApp app, RequestDetails details) => when(
    () => app.requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => Ok(details));

  Future<void> open(WidgetTester tester, ConsumerApp app) =>
      app.pump(tester, location: AppRoutes.request('request-1'));

  Future<void> tap(WidgetTester tester, ConsumerApp app, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await app.settle(tester);
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testConsumerApp('she cancels a request nobody answered yet', (
    tester,
    app,
  ) async {
    serve(app, liveRequest());
    when(
      () => app.requests.cancelRequest('request-1'),
    ).thenAnswer((_) async => const Ok(null));
    await open(tester, app);
    expect(find.byType(WaitingView), findsOneWidget);

    await tap(tester, app, find.text('الغي الطلب'));
    serve(
      app,
      liveRequest(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.consumer,
      ),
    );
    await tap(tester, app, inDialog('الغي الطلب'));

    verify(() => app.requests.cancelRequest('request-1')).called(1);
    expect(find.byType(ClosedRequestView), findsOneWidget);
    expect(find.text('لغيتي الطلب ده'), findsOneWidget);
  });

  testConsumerApp('she widens the time', (tester, app) async {
    serve(app, liveRequest());
    when(
      () => app.requests.widenRequestWindow('request-1'),
    ).thenAnswer((_) async => const Ok(null));
    await open(tester, app);

    await tap(tester, app, find.text('وسّعي المعاد عشان العروض تيجي أسرع'));
    serve(app, liveRequest(window: RequestWindow.anyTime));
    await tap(tester, app, inDialog('وسّعي المعاد'));

    verify(() => app.requests.widenRequestWindow('request-1')).called(1);
    expect(find.text(l10n.waitingWindowWidened('ms')), findsOneWidget);
    expect(
      find.text('وسّعي المعاد عشان العروض تيجي أسرع'),
      findsNothing,
    );
  });

  testConsumerApp('she picks an offer', (tester, app) async {
    serve(app, liveRequest(offers: liveOffers()));
    when(
      () => app.requests.acceptOffer('offer-1'),
    ).thenAnswer((_) async => const Ok(null));
    await open(tester, app);
    expect(find.byType(OffersView), findsOneWidget);

    await tap(tester, app, find.text('اختاري ياسر'));
    expect(find.text('تختاري ياسر؟'), findsOneWidget);
    serve(
      app,
      testRequestDetails(
        offers: testOffers(),
        job: testRequestJob(status: JobStatus.unconfirmed),
      ),
    );
    await tap(tester, app, inDialog('اختاري ياسر'));

    verify(() => app.requests.acceptOffer('offer-1')).called(1);
    expect(find.byType(TrackView), findsOneWidget);
  });

  testConsumerApp("she picks an offer on the technician's page", (
    tester,
    app,
  ) async {
    serve(app, liveRequest(offers: liveOffers()));
    when(
      () => app.requests.fetchTechnician('tech-2'),
    ).thenAnswer(
      (_) async => Ok(
        testTechnicianProfile(
          card: liveOffers().first.technician,
        ),
      ),
    );
    when(
      () => app.requests.acceptOffer('offer-1'),
    ).thenAnswer((_) async => const Ok(null));
    await open(tester, app);

    await tap(tester, app, find.text(l10n.offersProfile).first);
    expect(find.byType(TechnicianProfilePage), findsOneWidget);
    expect(find.text('ياسر عبد الحميد'), findsOneWidget);
    expect(find.text('موثّق بالبطاقة'), findsOneWidget);

    serve(
      app,
      testRequestDetails(
        offers: testOffers(),
        job: testRequestJob(status: JobStatus.unconfirmed),
      ),
    );
    await tap(tester, app, find.text('اختاري ياسر · 400 ج.م'));

    verify(() => app.requests.acceptOffer('offer-1')).called(1);
    expect(find.byType(TechnicianProfilePage), findsNothing);
    expect(find.byType(TrackView), findsOneWidget);
  });

  testConsumerApp('she asks a technician from his page', (tester, app) async {
    when(
      () => app.requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(testTechnicianProfile()));
    await app.pump(tester);

    unawaited(app.router(tester).push(AppRoutes.technicianProfile('tech-1')));
    await app.settle(tester);
    expect(find.text('فني تكييف · 12 سنة خبرة'), findsOneWidget);

    await tap(tester, app, find.text('اطلبي محمود'));

    final page = tester.widget<NewRequestPage>(find.byType(NewRequestPage));
    expect(page.categoryId, 'ac');
    expect(page.technicianId, 'tech-1');
  });

  testConsumerApp('she asks again after the time passed', (tester, app) async {
    serve(
      app,
      liveRequest(status: RequestStatus.expired, day: dayFromToday(-1)),
    );
    await open(tester, app);
    expect(
      find.text('محدش بعت عرض في الوقت ده، ورصيدك رجعلك'),
      findsOneWidget,
    );

    await tap(tester, app, find.text('اطلبي تاني'));

    final page = tester.widget<NewRequestPage>(find.byType(NewRequestPage));
    expect(page.categoryId, 'ac');
    expect(page.technicianId, isNull);
  });
}
