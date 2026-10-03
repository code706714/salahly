import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/cubit/jobs_list_cubit.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/jobs_page.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_list_card.dart';

import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/job_list_fixtures.dart';
import '../../../../helpers/job_seed.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockJobsListCubit extends MockCubit<JobsListState>
    implements JobsListCubit {}

void main() {
  late _MockJobsListCubit cubit;
  late MockSyncCubit sync;
  final now = DateTime(2026, 10, 2, 11);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
  });

  setUp(() {
    cubit = _MockJobsListCubit();
    sync = MockSyncCubit();
    when(() => sync.state).thenReturn(const SyncState());
  });

  void show(JobsListState state) => when(() => cubit.state).thenReturn(state);

  JobsListState loaded({
    JobsTab tab = JobsTab.upcoming,
    List<JobsSection> upcoming = const [],
    List<JobsSection> followUp = const [],
    List<JobsSection> done = const [],
    bool isSearching = false,
    String query = '',
  }) => JobsListState(
    now: now,
    tab: tab,
    isSearching: isSearching,
    query: query,
    upcoming: upcoming,
    followUp: followUp,
    done: done,
  );

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    const JobsView(),
    blocs: [
      BlocProvider<JobsListCubit>.value(value: cubit),
      BlocProvider<SyncCubit>.value(value: sync),
    ],
    stubRoutes: [
      AppRoutes.technicianCalendar,
      AppRoutes.newJob,
      AppRoutes.job('job-1'),
    ],
  );

  final sherif = testSummary(
    listedJob(
      tags: const [JobTag.installation],
      scheduledAt: DateTime(2026, 10, 2, 13),
    ),
    customerName: 'م. شريف عادل',
    totalPiastres: 145000,
  );
  final nadia = testSummary(
    listedJob(
      id: 'nadia',
      tags: const [],
      description: 'التكييف بيفصل لوحده',
      status: JobStatus.unconfirmed,
      scheduledAt: DateTime(2026, 10, 2, 16, 30),
    ),
    customerName: 'مدام نادية سمير',
  );
  final nourhan = testSummary(
    listedJob(
      id: 'nourhan',
      tags: const [JobTag.notCooling],
      scheduledAt: DateTime(2026, 10, 3, 12),
      source: JobSource.platform,
    ),
    customerName: 'نورهان م.',
    totalPiastres: 35000,
    isSynced: false,
  );
  final yasmin = testSummary(
    listedJob(
      id: 'yasmin',
      tags: const [JobTag.removal],
      status: JobStatus.unconfirmed,
      scheduledAt: DateTime(2026, 10, 5, 18),
      quoteStatus: QuoteStatus.sent,
      quoteSentAt: DateTime(2026, 9, 30, 20),
    ),
    customerName: 'ياسمين فؤاد',
    totalPiastres: 60000,
  );

  group('upcoming', () {
    final state = loaded(
      upcoming: [
        DaySection(DateTime(2026, 10, 2), [sherif, nadia]),
        DaySection(DateTime(2026, 10, 3), [nourhan]),
        DaySection(DateTime(2026, 10, 5), [yasmin]),
      ],
      followUp: [
        QuotesWaitingSection([yasmin]),
      ],
    );

    testWidgets('lists the coming visits by day', (tester) async {
      show(state);
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.navJobs), findsOneWidget);
      expect(
        find.text(l10n.jobsListTabCount(l10n.jobsListUpcoming, 4)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.jobsListTabCount(l10n.jobsListFollowUp, 1)),
        findsOneWidget,
      );
      expect(find.text(l10n.jobsListDone), findsOneWidget);
      expect(
        find.text('${l10n.today} · ${weekdayDate(DateTime(2026, 10, 2))}'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.tomorrow} · ${weekdayName(DateTime(2026, 10, 3))}'),
        findsOneWidget,
      );
      expect(find.text(weekdayDate(DateTime(2026, 10, 5))), findsOneWidget);
      expect(find.text('1:00'), findsOneWidget);
      expect(find.text('1,450'), findsOneWidget);
      expect(find.text(l10n.jobsListNoAmount), findsOneWidget);
      expect(find.text('التكييف بيفصل لوحده'), findsOneWidget);
      expect(find.text(l10n.jobStatusConfirmed), findsNWidgets(2));
      expect(find.text(l10n.jobStatusUnconfirmed), findsOneWidget);
      expect(find.text(l10n.jobFromPlatform), findsOneWidget);
      expect(find.text(l10n.newJob), findsOneWidget);
    });

    testWidgets('an unanswered quote says so instead of unconfirmed', (
      tester,
    ) async {
      show(state);
      await pumpView(tester);
      await tester.scrollUntilVisible(find.text('ياسمين فؤاد'), 200);

      expect(find.text(l10n.jobQuoteSent), findsOneWidget);
      expect(find.text(l10n.jobStatusUnconfirmed), findsOneWidget);
    });

    testWidgets('marks unsent work only while offline', (tester) async {
      show(state);
      await pumpView(tester);
      expect(find.text(l10n.jobPendingSync), findsNothing);

      when(() => sync.state).thenReturn(const SyncState(hasNetwork: false));
      await pumpView(tester);

      expect(find.text(l10n.jobPendingSync), findsOneWidget);
    });

    testWidgets('opens a job', (tester) async {
      show(state);
      await pumpView(tester);

      await tester.tap(find.text('م. شريف عادل'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('job-1')), findsOneWidget);
    });

    testWidgets('opens the calendar and a new job', (tester) async {
      show(state);
      await pumpView(tester);

      await tester.tap(find.byTooltip(l10n.jobsListCalendar));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.technicianCalendar), findsOneWidget);

      await pumpView(tester);
      await tester.tap(find.text(l10n.newJob));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.newJob), findsOneWidget);
    });

    testWidgets('switches tabs', (tester) async {
      show(state);
      await pumpView(tester);

      await tester.tap(find.text(l10n.jobsListDone));

      verify(() => cubit.selectTab(JobsTab.done)).called(1);
    });

    testWidgets('says when nothing is coming', (tester) async {
      show(loaded());
      await pumpView(tester);

      expect(find.text(l10n.jobsListNoUpcoming), findsOneWidget);
      expect(find.text(l10n.jobsListUpcoming), findsOneWidget);
    });

    testWidgets('shows only the header while loading', (tester) async {
      show(JobsListState(now: now));
      await pumpView(tester);

      expect(find.text(l10n.jobsListUpcoming), findsOneWidget);
      expect(find.text(l10n.jobsListNoUpcoming), findsNothing);
    });
  });

  group('search', () {
    testWidgets('opens, filters and closes', (tester) async {
      show(
        loaded(
          upcoming: [
            DaySection(DateTime(2026, 10, 2), [sherif]),
          ],
        ),
      );
      await pumpView(tester);

      await tester.tap(find.byTooltip(l10n.jobsListSearch));
      verify(() => cubit.openSearch()).called(1);

      show(
        loaded(
          upcoming: [
            DaySection(DateTime(2026, 10, 2), [sherif]),
          ],
          isSearching: true,
        ),
      );
      await pumpView(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.navJobs), findsNothing);

      await tester.enterText(find.byType(TextField), 'شريف');
      verify(() => cubit.search('شريف')).called(1);

      await tester.tap(find.byTooltip(l10n.jobsListSearchClose));
      verify(() => cubit.closeSearch()).called(1);
    });

    testWidgets('says when nothing matches', (tester) async {
      show(loaded(isSearching: true, query: 'زياد'));
      await pumpView(tester);

      expect(find.text(l10n.jobsListNoResults), findsOneWidget);
      expect(find.text(l10n.jobsListNoUpcoming), findsNothing);
    });
  });

  group('follow-up', () {
    final sohair = testSummary(
      listedJob(
        id: 'sohair',
        tags: const [JobTag.installation],
        status: JobStatus.finished,
        finishedAt: DateTime(2026, 9, 20),
      ),
      customerName: 'مدام سهير عبد الله',
      totalPiastres: 140000,
    );
    final karim = testSummary(
      listedJob(
        id: 'karim',
        tags: const [JobTag.maintenance],
        status: JobStatus.finished,
        finishedAt: DateTime(2026, 9, 26),
      ),
      totalPiastres: 170000,
      paidPiastres: 50000,
    );
    final hala = testSummary(
      listedJob(
        id: 'hala',
        status: JobStatus.finished,
        finishedAt: DateTime(2026, 10, 2, 10),
      ),
      customerName: 'أ. هالة فتحي',
      totalPiastres: 65000,
    );
    final missed = testSummary(
      listedJob(id: 'missed', scheduledAt: DateTime(2026, 10, 1, 13)),
      customerName: 'أ. وليد حسني',
    );
    final undated = testSummary(
      listedJob(id: 'undated', status: JobStatus.unconfirmed),
      customerName: 'دعاء م.',
    );

    testWidgets('groups what needs following up', (tester) async {
      show(
        loaded(
          tab: JobsTab.followUp,
          followUp: [
            AwaitingPaymentSection([sohair, karim, hala]),
            QuotesWaitingSection([yasmin]),
            MissedSection([missed]),
            UnscheduledSection([undated]),
          ],
        ),
      );
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobsListAwaitingPayment), findsOneWidget);
      expect(find.text(l10n.dueLate(12)), findsOneWidget);
      expect(
        find.text('${l10n.jobsListPartlyPaid} · ${l10n.dueLate(6)}'),
        findsOneWidget,
      );
      // What is still owed, not the whole bill.
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text(l10n.dueToday), findsOneWidget);

      await tester.scrollUntilVisible(find.text('دعاء م.'), 200);
      expect(find.text(l10n.jobsListQuotesWaiting), findsOneWidget);
      expect(find.text(l10n.jobsListQuoteSentAgo(2)), findsOneWidget);
      expect(find.text(l10n.jobsListMissed), findsOneWidget);
      expect(find.text(l10n.jobsListWasDue(l10n.yesterday)), findsOneWidget);
      expect(find.text(l10n.jobsListUnscheduled), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says when nothing needs following up', (tester) async {
      show(loaded(tab: JobsTab.followUp));
      await pumpView(tester);

      expect(find.text(l10n.jobsListNoFollowUp), findsOneWidget);
    });
  });

  group('done', () {
    JobSummary closed(
      String id,
      JobStatus status, {
      int total = 65000,
      int paid = 0,
    }) => testSummary(
      listedJob(
        id: id,
        status: status,
        finishedAt: status == JobStatus.cancelled ? null : DateTime(2026, 10),
        cancelledAt: status == JobStatus.cancelled ? DateTime(2026, 10) : null,
      ),
      customerName: 'عميل $id',
      totalPiastres: total,
      paidPiastres: paid,
    );

    testWidgets('groups by week and month with where each stands', (
      tester,
    ) async {
      show(
        loaded(
          tab: JobsTab.done,
          done: [
            ThisWeekSection([
              closed('paid', JobStatus.paid, paid: 65000),
              closed('owed', JobStatus.finished),
              closed('part', JobStatus.finished, paid: 20000),
            ]),
            LastWeekSection([closed('free', JobStatus.finished, total: 0)]),
            MonthSection(DateTime(2026, 8), [
              closed('cancelled', JobStatus.cancelled),
            ]),
            MonthSection(DateTime(2025, 12), [
              closed('old', JobStatus.paid, paid: 65000),
            ]),
          ],
        ),
      );
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobsListThisWeek), findsOneWidget);
      expect(
        find.text('${l10n.jobStatusFinished} · ${l10n.jobStatusPaid}'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.jobStatusFinished} · ${l10n.jobsListAwaitingMoney}'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.jobStatusFinished} · ${l10n.jobsListPartlyPaid}'),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(find.text('عميل old'), 200);
      expect(find.text(l10n.jobsListLastWeek), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(JobListCard),
          matching: find.text(l10n.jobStatusFinished),
        ),
        findsOneWidget,
      );
      expect(find.text('أغسطس'), findsOneWidget);
      expect(find.text(l10n.jobStatusCancelled), findsOneWidget);
      expect(find.text('ديسمبر 2025'), findsOneWidget);
    });

    testWidgets('says when nothing is done yet', (tester) async {
      show(loaded(tab: JobsTab.done));
      await pumpView(tester);

      expect(find.text(l10n.jobsListNoDone), findsOneWidget);
    });
  });

  group('on the real database', () {
    testTechnicianApp('the tab follows jobs through their life', (
      tester,
      app,
    ) async {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      late String sherif;
      late String sherifJob;
      late String owed;
      await tester.runAsync(() async {
        sherif = await seedCustomer(app, 'م. شريف عادل', phone: '01002345678');
        sherifJob = await seedJob(
          app,
          sherif,
          tags: const [JobTag.installation],
          at: DateTime(day.year, day.month, day.day + 1, 13),
          price: 145000,
          advance: 1,
        );
        final hala = await seedCustomer(app, 'أ. هالة فتحي');
        owed = await seedJob(
          app,
          hala,
          tags: const [JobTag.cleaning],
          price: 65000,
          advance: 3,
        );
        final undated = await seedCustomer(app, 'دعاء م.');
        await seedJob(app, undated, description: 'كشف على تكييف');
      });
      await app.pump(tester, location: AppRoutes.technicianJobs);

      expect(find.text('م. شريف عادل'), findsOneWidget);
      expect(find.text('1,450'), findsOneWidget);
      expect(
        find.text(l10n.jobsListTabCount(l10n.jobsListFollowUp, 2)),
        findsOneWidget,
      );

      await tester.tap(
        find.text(l10n.jobsListTabCount(l10n.jobsListFollowUp, 2)),
      );
      await app.settle(tester);
      expect(find.text('أ. هالة فتحي'), findsOneWidget);
      expect(find.text(l10n.dueToday), findsOneWidget);
      expect(find.text('دعاء م.'), findsOneWidget);

      await tester.runAsync(
        () => app.jobs.recordPayment(
          owed,
          amountPiastres: 65000,
          method: PaymentMethod.cash,
        ),
      );
      await app.settle(tester);
      expect(find.text('أ. هالة فتحي'), findsNothing);

      await tester.tap(find.text(l10n.jobsListDone));
      await app.settle(tester);
      expect(find.text('أ. هالة فتحي'), findsOneWidget);
      expect(
        find.text('${l10n.jobStatusFinished} · ${l10n.jobStatusPaid}'),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip(l10n.jobsListSearch));
      await app.settle(tester);
      await tester.enterText(find.byType(TextField), '0100 234');
      await app.settle(tester);
      expect(find.text(l10n.jobsListNoResults), findsOneWidget);
      await tester.tap(
        find.text(l10n.jobsListTabCount(l10n.jobsListUpcoming, 1)),
      );
      await app.settle(tester);
      expect(find.text('م. شريف عادل'), findsOneWidget);

      await tester.tap(find.text('م. شريف عادل'));
      await app.settle(tester);
      expect(find.byType(JobPage), findsOneWidget);
      expect(tester.widget<JobPage>(find.byType(JobPage)).jobId, sherifJob);
    });
  });
}
