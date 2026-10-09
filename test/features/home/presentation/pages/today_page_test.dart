import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/home/presentation/cubit/today_cubit.dart';
import 'package:salahly/features/home/presentation/pages/today_page.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/notification_fixtures.dart';
import '../../../../pump_app.dart';

class _MockTodayCubit extends MockCubit<TodayState> implements TodayCubit {}

SessionReady signedInTechnician([
  VerificationStatus status = VerificationStatus.approved,
]) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(verificationStatus: status, jobCredits: 3),
  ),
);

void main() {
  late MockSessionCubit session;
  late _MockTodayCubit today;
  late MockSyncCubit sync;
  late MockAreasCubit areas;
  late MockExternalApps apps;
  late MockIncomingRequestsCubit incoming;
  late MockCategoriesCubit categories;
  final morning = DateTime(2026, 10, 2, 11);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    final phone = PhoneNumber.tryParse('01000000000')!;
    registerFallbackValue(phone);
  });

  setUp(() {
    session = MockSessionCubit();
    today = _MockTodayCubit();
    sync = MockSyncCubit();
    areas = MockAreasCubit();
    apps = MockExternalApps();
    incoming = MockIncomingRequestsCubit();
    categories = MockCategoriesCubit();
    when(() => incoming.state).thenReturn(const IncomingRequestsState());
    when(() => categories.state).thenReturn(
      const CategoriesState(categories: TestCategories.all),
    );
    when(() => session.state).thenReturn(signedInTechnician());
    when(() => sync.state).thenReturn(const SyncState());
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
  });

  void showDay(TodayState state) => when(() => today.state).thenReturn(state);

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const TodayView(),
    repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
    blocs: [
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<TodayCubit>.value(value: today),
      BlocProvider<SyncCubit>.value(value: sync),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
      BlocProvider<IncomingRequestsCubit>.value(value: incoming),
      BlocProvider<NotificationsCubit>.value(value: mockNotificationsCubit()),
    ],
    stubRoutes: [
      AppRoutes.technicianAccount,
      AppRoutes.technicianMoney,
      AppRoutes.newJob,
      AppRoutes.newCustomer,
      AppRoutes.job('job-1'),
      AppRoutes.incomingRequests,
    ],
  );

  JobSummary visit({
    String id = 'job-1',
    int hour = 13,
    JobStatus status = JobStatus.confirmed,
    bool isSynced = true,
  }) => testSummary(
    testJob(
      id: id,
      tags: [JobTag.installation],
      scheduledAt: DateTime(2026, 10, 2, hour),
      status: status,
    ),
    customerName: 'م. شريف عادل',
    customerAreaId: 'heliopolis',
    customerAddress: '12 شارع الأهرام',
    isSynced: isSynced,
  );

  group('first day', () {
    setUp(
      () =>
          showDay(TodayState(now: morning, schedule: const [], hasJobs: false)),
    );

    testWidgets('welcomes the technician and shows how to start', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.greeting('محمود')), findsOneWidget);
      expect(find.text(l10n.todayStepFirstJob), findsOneWidget);
      expect(find.text(l10n.newJob), findsNothing);
    });

    testWidgets('starts the first job', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.todayStepFirstJob));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newJob), findsOneWidget);
    });

    testWidgets('brings customers in from the contacts', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.todayStepContacts));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newCustomer), findsOneWidget);
    });
  });

  group('a working day', () {
    testWidgets('greets by the part of the day', (tester) async {
      showDay(TodayState(now: morning, schedule: const [], hasJobs: true));
      await pumpPage(tester);
      expect(find.text(l10n.goodMorning('محمود')), findsOneWidget);
      expect(find.text(l10n.todayNoJobs), findsOneWidget);

      showDay(
        TodayState(
          now: DateTime(2026, 10, 2, 18),
          schedule: const [],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);
      expect(find.text(l10n.goodEvening('محمود')), findsOneWidget);
    });

    testWidgets('lists the visits with the next one marked', (tester) async {
      showDay(
        TodayState(
          now: morning,
          schedule: [
            visit(id: 'done', hour: 9, status: JobStatus.finished),
            visit(),
          ],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobCount(2)), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text(l10n.periodNoon), findsOneWidget);
      expect(find.text(l10n.jobNext), findsOneWidget);
      expect(find.text('12 شارع الأهرام، مصر الجديدة'), findsNWidgets(2));
      expect(find.text(l10n.newJob), findsOneWidget);
    });

    testWidgets('opens a visit', (tester) async {
      showDay(TodayState(now: morning, schedule: [visit()], hasJobs: true));
      await pumpPage(tester);

      await tester.tap(find.text('م. شريف عادل'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('job-1')), findsOneWidget);
    });

    testWidgets('asks the customer to confirm on WhatsApp', (tester) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => true);
      showDay(
        TodayState(
          now: morning,
          schedule: [visit(status: JobStatus.unconfirmed)],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.jobSendConfirmation));
      await tester.pump();

      final text =
          verify(
                () => apps.whatsApp(
                  text: captureAny(named: 'text'),
                  to: PhoneNumber.tryParse('01228703314'),
                ),
              ).captured.single
              as String;
      expect(text, contains('النهارده الساعة 1:00 الضهر'));
      expect(text, endsWith('محمود عبد الله'));
    });

    testWidgets('says so when WhatsApp does not open', (tester) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => false);
      showDay(
        TodayState(
          now: morning,
          schedule: [visit(status: JobStatus.unconfirmed)],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.jobSendConfirmation));
      await tester.pump();

      expect(find.text(l10n.whatsappFailed), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
    });

    testWidgets('shows the money still out and goes to it', (tester) async {
      showDay(
        TodayState(
          now: morning,
          schedule: const [],
          hasJobs: true,
          awaitingPayment: [
            testSummary(
              testJob(
                status: JobStatus.finished,
                finishedAt: DateTime(2026, 9, 20),
              ),
              totalPiastres: 385000,
            ),
          ],
        ),
      );
      await pumpPage(tester);

      expect(find.text(l10n.todayOwedTitle), findsOneWidget);
      expect(find.textContaining('3,850', findRichText: true), findsOneWidget);
      expect(
        find.text(l10n.todayOwedCustomers(1) + l10n.todayOwedLatest(12)),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.todayOwedSeeWho));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianMoney), findsOneWidget);
    });

    testWidgets('marks unsent work while offline', (tester) async {
      when(
        () => sync.state,
      ).thenReturn(const SyncState(hasNetwork: false, pendingChanges: 1));
      showDay(
        TodayState(
          now: morning,
          schedule: [visit(isSynced: false)],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);

      expect(find.text(l10n.jobPendingSync), findsOneWidget);
      expect(
        find.textContaining(l10n.offlinePending(1), findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('marks a price change the consumer declined', (tester) async {
      showDay(
        TodayState(
          now: morning,
          schedule: [
            testSummary(
              testJob(
                scheduledAt: DateTime(2026, 10, 2, 13),
                quoteStatus: QuoteStatus.declined,
                source: JobSource.platform,
              ),
              customerName: 'نورهان م.',
            ),
          ],
          hasJobs: true,
        ),
      );
      await pumpPage(tester);

      expect(find.text(l10n.platformJobQuoteDeclined), findsOneWidget);
      expect(find.text(l10n.jobFromPlatform), findsOneWidget);
    });

    testWidgets('opens the account from the avatar', (tester) async {
      showDay(TodayState(now: morning, schedule: const [], hasJobs: true));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.myAccount));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianAccount), findsOneWidget);
    });
  });

  group('verification', () {
    setUp(
      () =>
          showDay(TodayState(now: morning, schedule: const [], hasJobs: true)),
    );

    testWidgets('says the ID is being reviewed while pending', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.pending));
      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techPendingTitle, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('asks for new photos when rejected', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.rejected));
      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techRejectedTitle, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows no banner once approved', (tester) async {
      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techPendingTitle, findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining(l10n.techRejectedTitle, findRichText: true),
        findsNothing,
      );
    });
  });

  testWidgets('shows nothing while signing out', (tester) async {
    when(() => session.state).thenReturn(const SessionSignedOut());
    showDay(TodayState(now: morning));
    await pumpPage(tester);

    expect(find.textContaining('محمود'), findsNothing);
  });
  group('new requests', () {
    final workingDay = TodayState(
      now: morning,
      schedule: const [],
      hasJobs: true,
    );

    void showRequests(List<IncomingRequest> requests) =>
        when(
          () => incoming.state,
        ).thenReturn(
          IncomingRequestsState(
            status: IncomingRequestsStatus.ready,
            requests: requests,
          ),
        );

    testWidgets('names the area they are all in and the free jobs left', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(smallPhone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      showDay(workingDay);
      showRequests([
        testIncoming(),
        testIncoming(id: 'request-2', honorific: Honorific.mr),
      ]);
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('2'), findsOneWidget);
      expect(find.text(l10n.todayRequestsInArea(2, 'مدينة نصر')), findsOne);
      expect(find.text(l10n.todayRequestsNeedMany('تكييف')), findsOneWidget);
      expect(find.text(l10n.todayRequestsCreditsLeft(3)), findsOneWidget);
      expect(
        find.text(
          '${l10n.todayRequestsBalance} ${l10n.todayRequestsBalanceCount(3)}',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('speaks of one consumer by their gender', (tester) async {
      showDay(workingDay);
      showRequests([testIncoming(honorific: Honorific.mr)]);
      await pumpPage(tester);

      expect(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')), findsOne);
      expect(
        find.text(l10n.todayRequestsNeedOne('mr', 'تكييف')),
        findsOneWidget,
      );
    });

    testWidgets('speaks generally of requests in several areas', (
      tester,
    ) async {
      showDay(workingDay);
      showRequests([
        testIncoming(),
        testIncoming(id: 'request-2', areaId: 'maadi'),
        testIncoming(id: 'request-3', areaId: 'zamalek'),
      ]);
      await pumpPage(tester);

      expect(find.text(l10n.todayRequestsNearby(3)), findsOneWidget);
    });

    testWidgets('leaves out requests already answered or closed', (
      tester,
    ) async {
      showDay(workingDay);
      showRequests([
        testIncoming(myOffer: testMyOffer()),
        testIncoming(id: 'request-2', dismissed: true),
        testIncoming(id: 'request-3', offerCount: 5),
      ]);
      await pumpPage(tester);

      expect(find.text(l10n.todayRequestsNearby(1)), findsNothing);
      expect(find.text(l10n.todayRequestsCreditsLeft(3)), findsNothing);
      expect(
        find.text(
          '${l10n.todayRequestsBalance} ${l10n.todayRequestsBalanceCount(3)}',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens the new requests', (tester) async {
      showDay(workingDay);
      showRequests([testIncoming()]);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.incomingRequests), findsOneWidget);
    });

    testWidgets('shows on the first day too', (tester) async {
      showDay(TodayState(now: morning, schedule: const [], hasJobs: false));
      showRequests([testIncoming()]);
      await pumpPage(tester);

      expect(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')), findsOne);
      expect(find.text(l10n.todayStepFirstJob), findsOneWidget);
    });

    testWidgets('a technician not verified yet gets no requests', (
      tester,
    ) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.pending));
      showDay(workingDay);
      showRequests([testIncoming()]);
      await pumpPage(tester);

      expect(find.text(l10n.todayRequestsInArea(1, 'مدينة نصر')), findsNothing);
      expect(find.textContaining(l10n.todayRequestsBalance), findsNothing);
    });
  });
}
