import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/home/presentation/cubit/consumer_home_cubit.dart';
import 'package:salahly/features/home/presentation/pages/consumer_home_page.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/request_page.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late MockConsumerHomeCubit home;

  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
    registerConsumerScreenFallbacks();
  });

  const ready = ConsumerHomeState(
    categories: TestCategories.all,
    selectedId: 'ac',
    technicianCounts: {'ac': 24},
  );

  setUp(() {
    home = MockConsumerHomeCubit();
    when(() => home.state).thenReturn(ready);
    when(home.refresh).thenAnswer((_) async {});
  });

  Future<ConsumerScreenBlocs> pumpView(
    WidgetTester tester, {
    ConsumerScreenBlocs? blocs,
    ConsumerHomeState state = ready,
  }) async {
    when(() => home.state).thenReturn(state);
    final scope = blocs ?? ConsumerScreenBlocs();
    await tester.pumpApp(
      BlocProvider<ConsumerHomeCubit>.value(
        value: home,
        child: const ConsumerHomeView(),
      ),
      blocs: scope.providers,
      stubRoutes: [
        AppRoutes.request('request-1'),
        AppRoutes.newRequest,
      ],
    );
    return scope;
  }

  group('ConsumerHomeView', () {
    testWidgets('greets her by first name and asks what needs fixing on a '
        'small phone', (tester) async {
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('مدينة نصر'), findsOneWidget);
      expect(
        find.text(
          '${l10n.greeting('نورهان')}\n${l10n.consumerHomeQuestion('ms')}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.consumerHomeWhyTitle('ms')), findsOneWidget);
      expect(find.text(l10n.consumerHomeWhyPrice('ms')), findsOneWidget);
    });

    testWidgets('speaks to a man in his words', (tester) async {
      await pumpView(
        tester,
        blocs: ConsumerScreenBlocs(
          session: testConsumerSession(
            honorific: Honorific.mr,
            fullName: 'كريم سامي',
          ),
        ),
      );

      expect(
        find.text(
          '${l10n.greeting('كريم')}\n${l10n.consumerHomeQuestion('other')}',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(l10n.consumerHomeCreditsLead('other')),
        findsOneWidget,
      );
      expect(find.text(l10n.newRequestTitle('other', 'تكييف')), findsOneWidget);
    });

    for (final credits in [1, 2, 4, 12]) {
      testWidgets('says $credits free requests are left', (tester) async {
        await pumpView(
          tester,
          blocs: ConsumerScreenBlocs(
            session: testConsumerSession(requestCredits: credits),
          ),
        );

        expect(
          find.text(
            '${l10n.consumerHomeCreditsLead('ms')} '
            '${l10n.consumerHomeCreditsCount(credits)}',
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('says when the free requests are used up', (tester) async {
      await pumpView(
        tester,
        blocs: ConsumerScreenBlocs(
          session: testConsumerSession(requestCredits: 0),
        ),
      );

      expect(find.text(l10n.consumerCreditsLeft(0)), findsOneWidget);
    });

    testWidgets('shows the categories, with the technicians nearby and the '
        'ones coming soon', (tester) async {
      await pumpView(tester);

      expect(find.text('تكييف'), findsOneWidget);
      expect(find.text(l10n.consumerHomeTechnicians(24)), findsOneWidget);
      for (final name in ['كهربا', 'سباكة', 'غسالات وتلاجات']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text(l10n.consumerHomeSoon), findsNWidgets(3));
    });

    testWidgets('picks an open category, not one coming soon', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text('تكييف'));
      verify(() => home.select('ac')).called(1);

      await tester.tap(find.text('سباكة'));
      verifyNever(() => home.select('plumbing'));
    });

    testWidgets('asks for a technician of the picked category', (
      tester,
    ) async {
      await pumpView(tester);

      await tester.tap(find.text(l10n.newRequestTitle('ms', 'تكييف')));
      await tester.pumpAndSettle();

      final stub = find.text(AppRoutes.newRequest);
      expect(stub, findsOneWidget);
      expect(
        GoRouterState.of(tester.element(stub)).uri.toString(),
        AppRoutes.newRequestFor(categoryId: 'ac'),
      );
    });

    testWidgets('has no request button until a category is open', (
      tester,
    ) async {
      await pumpView(tester, state: const ConsumerHomeState());

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(l10n.consumerHomeSoon), findsNothing);
    });

    group('the request in progress', () {
      for (final (name, request, line, action) in [
        (
          'waiting for offers',
          testRequestSummary(),
          l10n.consumerHomeWaiting,
          l10n.consumerHomeFollow('ms'),
        ),
        (
          'with offers',
          testRequestSummary(offerCount: 3),
          l10n.consumerHomeOffers(3, 'ms'),
          l10n.consumerHomeSeeOffers('ms'),
        ),
        (
          'with one offer',
          testRequestSummary(offerCount: 1),
          l10n.consumerHomeOffers(1, 'ms'),
          l10n.consumerHomeSeeOffers('ms'),
        ),
        (
          'with a technician picked',
          testRequestSummary(
            status: RequestStatus.assigned,
            technicianName: 'محمود السيد',
            jobStatus: JobStatus.unconfirmed,
          ),
          l10n.consumerHomeChosen('ms', 'محمود'),
          l10n.consumerHomeFollow('ms'),
        ),
        (
          'with the technician working',
          testRequestSummary(
            status: RequestStatus.assigned,
            technicianName: 'محمود السيد',
            jobStatus: JobStatus.started,
          ),
          l10n.consumerHomeStarted('محمود'),
          l10n.consumerHomeFollow('ms'),
        ),
      ]) {
        testWidgets(name, (tester) async {
          await pumpView(
            tester,
            blocs: ConsumerScreenBlocs(requests: [request]),
          );

          expect(tester.takeException(), isNull);
          expect(
            find.text(
              l10n.consumerHomeRequestLabel(
                requestTitle(l10n, RequestIssue.notCooling, category: 'تكييف'),
              ),
            ),
            findsOneWidget,
          );
          expect(find.text(line), findsOneWidget);
          expect(find.text(action), findsOneWidget);
        });
      }

      testWidgets('says when the technician is coming', (tester) async {
        await pumpView(
          tester,
          blocs: ConsumerScreenBlocs(
            requests: [
              testRequestSummary(
                status: RequestStatus.assigned,
                technicianName: 'محمود السيد',
                jobStatus: JobStatus.confirmed,
              ),
            ],
          ),
        );

        expect(find.textContaining('محمود جاي'), findsOneWidget);
        expect(find.textContaining('12:00'), findsOneWidget);
      });

      testWidgets('shows the newest one in progress and opens it', (
        tester,
      ) async {
        await pumpView(
          tester,
          blocs: ConsumerScreenBlocs(
            requests: [
              testRequestSummary(
                id: 'request-0',
                status: RequestStatus.expired,
              ),
              testRequestSummary(offerCount: 2),
              testRequestSummary(id: 'request-2', issue: RequestIssue.noisy),
            ],
          ),
        );

        expect(find.text(l10n.consumerHomeOffers(2, 'ms')), findsOneWidget);
        expect(find.text(l10n.consumerHomeWaiting), findsNothing);

        await tester.tap(find.text(l10n.consumerHomeSeeOffers('ms')));
        await tester.pumpAndSettle();

        expect(find.text(AppRoutes.request('request-1')), findsOneWidget);
      });

      testWidgets('is left out when none is in progress', (tester) async {
        await pumpView(
          tester,
          blocs: ConsumerScreenBlocs(
            requests: [
              testRequestSummary(
                status: RequestStatus.assigned,
                technicianName: 'محمود السيد',
                jobStatus: JobStatus.paid,
              ),
            ],
          ),
        );

        expect(find.textContaining('طلبك:'), findsNothing);
      });
    });

    testWidgets('pulling down refreshes the counts and the requests', (
      tester,
    ) async {
      final blocs = await pumpView(tester);

      await tester.fling(find.text('تكييف'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      verify(home.refresh).called(1);
      verify(blocs.myRequests.load).called(1);
    });

    testWidgets('takes the catalog when it arrives', (tester) async {
      final blocs = ConsumerScreenBlocs();
      final categories = StreamController<CategoriesState>();
      whenListen(
        blocs.categories,
        categories.stream,
        initialState: const CategoriesState(),
      );
      await pumpView(tester, blocs: blocs);

      categories.add(const CategoriesState(categories: TestCategories.all));
      await tester.pump();

      verify(() => home.useCategories(TestCategories.all)).called(1);
      await categories.close();
    });

    testWidgets('shows nothing while signing out', (tester) async {
      await pumpView(
        tester,
        blocs: ConsumerScreenBlocs(session: const SessionSignedOut()),
      );

      expect(find.textContaining(l10n.greeting('')), findsNothing);
    });
  });

  group('ConsumerHomePage', () {
    testConsumerApp('counts the technicians in her area for each open '
        'category, and asks for one', (tester, app) async {
      when(
        app.requests.fetchRequests,
      ).thenAnswer((_) async => Ok([testRequestSummary(offerCount: 3)]));
      await app.pump(tester);

      expect(find.text(l10n.consumerHomeTechnicians(24)), findsOneWidget);
      expect(find.text(l10n.consumerHomeOffers(3, 'ms')), findsOneWidget);
      verify(
        () => app.requests.availableTechnicianCount(
          categoryId: 'ac',
          areaId: 'nasr_city',
        ),
      ).called(1);
      verifyNever(
        () => app.requests.availableTechnicianCount(
          categoryId: 'plumbing',
          areaId: any(named: 'areaId'),
        ),
      );

      await tester.tap(find.text(l10n.newRequestTitle('ms', 'تكييف')));
      await app.settle(tester);

      expect(find.byType(NewRequestPage), findsOneWidget);
      expect(
        tester.widget<NewRequestPage>(find.byType(NewRequestPage)).categoryId,
        'ac',
      );
    });

    testConsumerApp('opens the request in progress', (tester, app) async {
      when(
        app.requests.fetchRequests,
      ).thenAnswer((_) async => Ok([testRequestSummary(offerCount: 3)]));
      when(
        () => app.requests.fetchRequest('request-1'),
      ).thenAnswer((_) async => Ok(testRequestDetails(offers: testOffers())));
      await app.pump(tester);

      await tester.tap(find.text(l10n.consumerHomeSeeOffers('ms')));
      await app.settle(tester);

      expect(find.byType(RequestPage), findsOneWidget);
      expect(
        tester.widget<RequestPage>(find.byType(RequestPage)).requestId,
        'request-1',
      );
    });
  });
}
