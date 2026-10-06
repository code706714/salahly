import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/presentation/pages/consumer_account_page.dart';
import 'package:salahly/features/home/presentation/pages/consumer_home_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/addresses_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/complaint_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/my_requests_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/past_technicians_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_profile_page.dart';

import '../../helpers/consumer_app.dart';
import '../../helpers/marketplace_fixtures.dart';
import '../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  testConsumerApp('a signed-in consumer lands on home', (tester, app) async {
    await app.pump(tester);

    expect(find.byType(ConsumerHomePage), findsOneWidget);
    expect(find.text(l10n.navMyRequests), findsOneWidget);
  });

  testConsumerApp('the tabs switch between the three main screens', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    for (final (label, page) in [
      (l10n.navMyRequests, MyRequestsPage),
      (l10n.navMyAccount, ConsumerAccountPage),
      (l10n.navHome, ConsumerHomePage),
    ]) {
      await tester.tap(find.text(label).last);
      await app.settle(tester);
      expect(find.byType(page), findsOneWidget, reason: label);
    }
  });

  testConsumerApp('fetches the requests once for every tab', (
    tester,
    app,
  ) async {
    await app.pump(tester);
    await tester.tap(find.text(l10n.navMyRequests).last);
    await app.settle(tester);

    verify(app.requests.fetchRequests).called(1);
  });

  group('screens pushed over the tabs', () {
    for (final (location, page) in [
      (AppRoutes.newRequest, NewRequestPage),
      (AppRoutes.request('request-1'), RequestPage),
      (AppRoutes.requestComplaint('request-1'), ComplaintPage),
      (AppRoutes.technicianProfile('tech-1'), TechnicianProfilePage),
      (AppRoutes.consumerAddresses, AddressesPage),
      (AppRoutes.pastTechnicians, PastTechniciansPage),
    ]) {
      testConsumerApp('$location opens $page without the tabs', (
        tester,
        app,
      ) async {
        when(
          () => app.requests.fetchRequest(any()),
        ).thenAnswer((_) async => Ok(testRequestDetails()));
        await app.pump(tester);

        unawaited(app.router(tester).push(location));
        await app.settle(tester);

        expect(find.byType(page), findsOneWidget);
        expect(find.text(l10n.navMyRequests), findsNothing);
      });
    }
  });

  testConsumerApp('passes the category and technician of a new request', (
    tester,
    app,
  ) async {
    when(
      () => app.requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(testTechnicianProfile()));
    await app.pump(tester);

    unawaited(
      app
          .router(tester)
          .push(
            AppRoutes.newRequestFor(categoryId: 'ac', technicianId: 'tech-1'),
          ),
    );
    await app.settle(tester);

    final page = tester.widget<NewRequestPage>(find.byType(NewRequestPage));
    expect(page.categoryId, 'ac');
    expect(page.technicianId, 'tech-1');
    expect(AppRoutes.newRequestFor(), AppRoutes.newRequest);
  });

  testConsumerApp('passes the offer a technician profile was opened from', (
    tester,
    app,
  ) async {
    await app.pump(tester);
    final offer = testOffer();

    unawaited(
      app
          .router(tester)
          .push(AppRoutes.technicianProfile('tech-1'), extra: offer),
    );
    await app.settle(tester);

    final page = tester.widget<TechnicianProfilePage>(
      find.byType(TechnicianProfilePage),
    );
    expect(page.technicianId, 'tech-1');
    expect(page.offer, offer);
  });

  testConsumerApp('a consumer cannot open technician screens', (
    tester,
    app,
  ) async {
    await app.pump(tester, location: AppRoutes.technicianJobs);

    expect(find.byType(ConsumerHomePage), findsOneWidget);
  });
}
