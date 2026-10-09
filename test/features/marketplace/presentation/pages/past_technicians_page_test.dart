import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/pages/past_technicians_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_profile_page.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    ConsumerApp.registerFallbacks();
  });

  RequestSummary hired({
    required String id,
    required String technicianId,
    required String name,
    RequestIssue issue = RequestIssue.notCooling,
  }) {
    final request = testRequestSummary(
      id: id,
      issue: issue,
      status: RequestStatus.assigned,
      jobStatus: JobStatus.paid,
      technicianName: name,
    );
    return RequestSummary(
      id: request.id,
      categoryId: request.categoryId,
      issue: request.issue,
      status: request.status,
      day: request.day,
      window: request.window,
      createdAt: request.createdAt,
      offerCount: request.offerCount,
      technicianId: technicianId,
      technicianName: name,
      jobStatus: request.jobStatus,
    );
  }

  final requests = [
    testRequestSummary(id: 'request-0', offerCount: 2),
    hired(id: 'request-1', technicianId: 'tech-1', name: 'محمود السيد'),
    hired(
      id: 'request-2',
      technicianId: 'tech-2',
      name: 'أحمد فتحي',
      issue: RequestIssue.leaking,
    ),
    hired(
      id: 'request-3',
      technicianId: 'tech-1',
      name: 'محمود السيد',
      issue: RequestIssue.installation,
    ),
  ];

  Future<ConsumerScreenBlocs> pumpPage(
    WidgetTester tester,
    ConsumerScreenBlocs blocs,
  ) async {
    await tester.pumpApp(
      const PastTechniciansPage(),
      blocs: blocs.providers,
      stubRoutes: [
        AppRoutes.technicianProfile('tech-1'),
        AppRoutes.technicianProfile('tech-2'),
      ],
    );
    return blocs;
  }

  test('lists each technician once, with their latest request', () {
    final technicians = PastTechniciansPage.fromRequests(requests);

    expect(technicians, [
      (id: 'tech-1', lastRequest: requests[1]),
      (id: 'tech-2', lastRequest: requests[2]),
    ]);
  });

  testWidgets('shows the technicians, newest first, on a small phone', (
    tester,
  ) async {
    await pumpPage(tester, ConsumerScreenBlocs(requests: requests));

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.pastTechniciansTitle), findsOneWidget);
    expect(find.text('محمود السيد'), findsOneWidget);
    expect(find.text('أحمد فتحي'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('محمود السيد')).dy,
      lessThan(tester.getTopLeft(find.text('أحمد فتحي')).dy),
    );
    expect(
      find.text(
        l10n.pastTechniciansLastRequest(
          requestTitle(l10n, RequestIssue.notCooling, category: 'تكييف'),
          '3 أكتوبر 2026',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('opens a technician', (tester) async {
    await pumpPage(tester, ConsumerScreenBlocs(requests: requests));

    await tester.tap(find.text('أحمد فتحي'));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.technicianProfile('tech-2')), findsOneWidget);
  });

  testWidgets('says when there is no technician yet', (tester) async {
    await pumpPage(
      tester,
      ConsumerScreenBlocs(
        requests: [testRequestSummary()],
        session: testConsumerSession(honorific: Honorific.mr),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.pastTechniciansEmpty('other')), findsOneWidget);
    expect(find.text(l10n.pastTechniciansEmptyNote('other')), findsOneWidget);
  });

  testWidgets('waits for the requests', (tester) async {
    await pumpPage(
      tester,
      ConsumerScreenBlocs(status: MyRequestsStatus.loading),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('retries requests that could not be fetched', (tester) async {
    final blocs = await pumpPage(
      tester,
      ConsumerScreenBlocs(status: MyRequestsStatus.failed),
    );

    expect(find.text(l10n.pastTechniciansLoadFailed), findsOneWidget);
    await tester.tap(find.text(l10n.consumerRetry('ms')));
    verify(blocs.myRequests.load).called(1);
  });

  testConsumerApp('opens from the account and shows a technician', (
    tester,
    app,
  ) async {
    when(app.requests.fetchRequests).thenAnswer((_) async => Ok(requests));
    when(
      () => app.requests.fetchListedTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(testTechnicianProfile()));
    await app.pump(tester, location: AppRoutes.consumerAccount);

    await tester.tap(find.text(l10n.pastTechniciansTitle));
    await app.settle(tester);
    expect(find.byType(PastTechniciansPage), findsOneWidget);

    await tester.tap(find.text('محمود السيد'));
    await app.settle(tester);

    expect(
      tester
          .widget<TechnicianProfilePage>(find.byType(TechnicianProfilePage))
          .technicianId,
      'tech-1',
    );
  });
}
