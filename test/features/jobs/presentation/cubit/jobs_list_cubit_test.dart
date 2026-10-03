import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/cubit/jobs_list_cubit.dart';

import '../../../../helpers/error_observer.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/job_list_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  // A Friday; the week started on Saturday the 26th.
  final now = DateTime(2026, 10, 2, 11);

  String describe(Job job) =>
      '${job.tags.map((tag) => tag.name).join(' ')} ${job.description ?? ''}';

  List<String> ids(JobsSection section) => [
    for (final summary in section.jobs) summary.job.id,
  ];

  group('upcomingSections', () {
    test('groups open jobs from the start of today by day', () {
      final sections = upcomingSections([
        testSummary(
          listedJob(id: 'yesterday', scheduledAt: DateTime(2026, 10, 1, 16)),
        ),
        testSummary(
          listedJob(id: 'sunday', scheduledAt: DateTime(2026, 10, 4, 10)),
        ),
        testSummary(
          listedJob(id: 'early', scheduledAt: DateTime(2026, 10, 2, 9)),
        ),
        testSummary(listedJob(id: 'no-date')),
        testSummary(
          listedJob(id: 'later', scheduledAt: DateTime(2026, 10, 2, 16, 30)),
        ),
      ], now: now);

      expect(sections, hasLength(2));
      expect((sections[0] as DaySection).day, DateTime(2026, 10, 2));
      expect(ids(sections[0]), ['early', 'later']);
      expect((sections[1] as DaySection).day, DateTime(2026, 10, 4));
      expect(ids(sections[1]), ['sunday']);
    });
  });

  group('followUpSections', () {
    test('lists money owed, unanswered quotes, missed and undated jobs', () {
      final sections = followUpSections(
        open: [
          testSummary(
            listedJob(id: 'missed', scheduledAt: DateTime(2026, 9, 30, 13)),
          ),
          testSummary(
            listedJob(
              id: 'quote-new',
              status: JobStatus.unconfirmed,
              scheduledAt: DateTime(2026, 10, 5, 18),
              quoteStatus: QuoteStatus.sent,
              quoteSentAt: DateTime(2026, 10),
            ),
          ),
          testSummary(
            listedJob(id: 'today', scheduledAt: DateTime(2026, 10, 2, 9)),
          ),
          testSummary(
            listedJob(
              id: 'quote-old',
              status: JobStatus.unconfirmed,
              scheduledAt: DateTime(2026, 9, 29, 10),
              quoteStatus: QuoteStatus.sent,
              quoteSentAt: DateTime(2026, 9, 28),
            ),
          ),
          testSummary(listedJob(id: 'no-date', status: JobStatus.unconfirmed)),
        ],
        awaitingPayment: [
          testSummary(
            listedJob(id: 'owed', status: JobStatus.finished),
            totalPiastres: 65000,
          ),
        ],
        now: now,
      );

      expect(sections.map((section) => section.runtimeType), [
        AwaitingPaymentSection,
        QuotesWaitingSection,
        MissedSection,
        UnscheduledSection,
      ]);
      expect(ids(sections[0]), ['owed']);
      // A quote past its day is listed once, with the quotes.
      expect(ids(sections[1]), ['quote-old', 'quote-new']);
      expect(ids(sections[2]), ['missed']);
      expect(ids(sections[3]), ['no-date']);
    });

    test('leaves out empty groups', () {
      expect(
        followUpSections(open: const [], awaitingPayment: const [], now: now),
        isEmpty,
      );
    });
  });

  group('doneSections', () {
    test('groups by this week from Saturday, last week, then month', () {
      final sections = doneSections(
        closed: [
          testSummary(
            listedJob(
              id: 'paid-today',
              status: JobStatus.paid,
              finishedAt: DateTime(2026, 10, 2, 10),
              paidAt: DateTime(2026, 10, 2, 10),
            ),
          ),
          testSummary(
            listedJob(
              id: 'cancelled-saturday',
              status: JobStatus.cancelled,
              cancelledAt: DateTime(2026, 9, 26, 8),
            ),
          ),
          testSummary(
            listedJob(
              id: 'last-friday',
              status: JobStatus.paid,
              finishedAt: DateTime(2026, 9, 25, 20),
            ),
          ),
          testSummary(
            listedJob(
              id: 'august',
              status: JobStatus.paid,
              finishedAt: DateTime(2026, 8, 30),
            ),
          ),
          testSummary(
            listedJob(
              id: 'september',
              status: JobStatus.paid,
              finishedAt: DateTime(2026, 9, 18),
            ),
          ),
        ],
        awaitingPayment: [
          testSummary(
            listedJob(
              id: 'owed-yesterday',
              status: JobStatus.finished,
              finishedAt: DateTime(2026, 10, 1, 15),
            ),
            totalPiastres: 60000,
          ),
          testSummary(
            listedJob(
              id: 'owed-last-week',
              status: JobStatus.finished,
              finishedAt: DateTime(2026, 9, 19),
            ),
            totalPiastres: 60000,
          ),
        ],
        now: now,
      );

      expect(sections.map((section) => section.runtimeType), [
        ThisWeekSection,
        LastWeekSection,
        MonthSection,
        MonthSection,
      ]);
      expect(ids(sections[0]), [
        'paid-today',
        'owed-yesterday',
        'cancelled-saturday',
      ]);
      expect(ids(sections[1]), ['last-friday', 'owed-last-week']);
      expect((sections[2] as MonthSection).month, DateTime(2026, 9));
      expect(ids(sections[2]), ['september']);
      expect((sections[3] as MonthSection).month, DateTime(2026, 8));
    });

    test('a job closed on a Saturday starts that week', () {
      final saturday = DateTime(2026, 10, 3, 9);
      final sections = doneSections(
        closed: [
          testSummary(
            listedJob(
              id: 'friday',
              status: JobStatus.paid,
              finishedAt: DateTime(2026, 10, 2, 18),
            ),
          ),
        ],
        awaitingPayment: const [],
        now: saturday,
      );

      expect(sections.single, isA<LastWeekSection>());
    });
  });

  group('matchesJobQuery', () {
    final summary = testSummary(
      listedJob(tags: const [], description: 'التكييف بينقط مية في الصالة'),
      customerName: 'أ. هالة فتحي',
      customerPhone: '01001234567',
    );

    bool matches(String query) =>
        matchesJobQuery(summary, query, describe: describe);

    test('finds by any part of the name, however the letters are typed', () {
      expect(matches('هاله'), isTrue);
      expect(matches(' ا. هالة '), isTrue);
      expect(matches('كريم'), isFalse);
    });

    test('finds by digits of the phone, in any form', () {
      expect(matches('0100 123'), isTrue);
      expect(matches('٠١٠٠١٢٣٤٥٦٧'), isTrue);
      expect(matches('+20 100 123 4567'), isTrue);
      expect(matches('0111'), isFalse);
    });

    test('finds by the work', () {
      expect(matches('الصاله'), isTrue);
      expect(matches('فريون'), isFalse);
    });

    test('an empty search matches everything', () {
      expect(matches('  '), isTrue);
    });
  });

  group('JobsListCubit', () {
    late MockJobsRepository jobs;
    late StreamController<List<JobSummary>> open;
    late StreamController<List<JobSummary>> awaiting;
    late StreamController<List<JobSummary>> closed;

    setUp(() {
      jobs = MockJobsRepository();
      open = StreamController.broadcast();
      awaiting = StreamController.broadcast();
      closed = StreamController.broadcast();
      when(() => jobs.watchOpen()).thenAnswer((_) => open.stream);
      when(
        () => jobs.watchAwaitingPayment(),
      ).thenAnswer((_) => awaiting.stream);
      when(() => jobs.watchClosed()).thenAnswer((_) => closed.stream);
    });

    JobsListCubit build({DateTime Function()? clock}) => JobsListCubit(
      jobs: jobs,
      describe: describe,
      clock: clock ?? () => now,
    )..start();

    final sherif = testSummary(
      listedJob(id: 'sherif', scheduledAt: DateTime(2026, 10, 2, 13)),
      customerName: 'م. شريف عادل',
      customerPhone: '01002345678',
    );
    final nadia = testSummary(
      listedJob(
        id: 'nadia',
        status: JobStatus.unconfirmed,
        scheduledAt: DateTime(2026, 10, 3, 16),
        quoteStatus: QuoteStatus.sent,
        quoteSentAt: DateTime(2026, 10),
      ),
      customerName: 'مدام نادية سمير',
      customerPhone: '01112345678',
    );
    final sohair = testSummary(
      listedJob(
        id: 'sohair',
        status: JobStatus.finished,
        finishedAt: DateTime(2026, 9, 20),
      ),
      customerName: 'مدام سهير عبد الله',
      customerPhone: null,
      totalPiastres: 140000,
    );
    final hala = testSummary(
      listedJob(
        id: 'hala',
        status: JobStatus.paid,
        finishedAt: DateTime(2026, 10),
      ),
      customerName: 'أ. هالة فتحي',
      totalPiastres: 65000,
      paidPiastres: 65000,
    );

    Future<JobsListCubit> loaded() async {
      final cubit = build();
      open.add([sherif, nadia]);
      awaiting.add([sohair]);
      closed.add([hala]);
      await pumpEventQueue();
      return cubit;
    }

    test('is loading until all three lists arrive', () async {
      final cubit = build();
      expect(cubit.state.isLoading, isTrue);

      open.add([sherif]);
      awaiting.add(const []);
      await pumpEventQueue();
      expect(cubit.state.isLoading, isTrue);
      expect(cubit.state.countOf(JobsTab.upcoming), 0);

      closed.add(const []);
      await pumpEventQueue();
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.upcoming, [
        DaySection(DateTime(2026, 10, 2), [sherif]),
      ]);
      await cubit.close();
    });

    test('sorts every list into its tab and counts distinct jobs', () async {
      final cubit = await loaded();

      expect(cubit.state.tab, JobsTab.upcoming);
      expect(cubit.state.countOf(JobsTab.upcoming), 2);
      expect(cubit.state.followUp, [
        AwaitingPaymentSection([sohair]),
        QuotesWaitingSection([nadia]),
      ]);
      expect(cubit.state.countOf(JobsTab.followUp), 2);
      expect(cubit.state.sectionsOf(JobsTab.done), [
        ThisWeekSection([hala]),
        LastWeekSection([sohair]),
      ]);
      await cubit.close();
    });

    test('follows the lists as they change', () async {
      final cubit = await loaded();

      open.add([sherif]);
      await pumpEventQueue();

      expect(cubit.state.countOf(JobsTab.upcoming), 1);
      expect(cubit.state.followUp, [
        AwaitingPaymentSection([sohair]),
      ]);
      await cubit.close();
    });

    test('switches tabs', () async {
      final cubit = await loaded();

      cubit.selectTab(JobsTab.done);

      expect(cubit.state.tab, JobsTab.done);
      await cubit.close();
    });

    test('searching filters every tab and closing shows all again', () async {
      final cubit = await loaded();

      cubit.openSearch();
      expect(cubit.state.isSearching, isTrue);

      cubit.search('سهير');
      expect(cubit.state.query, 'سهير');
      expect(cubit.state.upcoming, isEmpty);
      expect(cubit.state.followUp, [
        AwaitingPaymentSection([sohair]),
      ]);
      expect(cubit.state.done, [
        LastWeekSection([sohair]),
      ]);

      cubit.search('0111');
      expect(cubit.state.upcoming, [
        DaySection(DateTime(2026, 10, 3), [nadia]),
      ]);

      cubit.closeSearch();
      expect(cubit.state.isSearching, isFalse);
      expect(cubit.state.query, isEmpty);
      expect(cubit.state.countOf(JobsTab.upcoming), 2);
      await cubit.close();
    });

    test('keeps the search while the lists change', () async {
      final cubit = await loaded();
      cubit
        ..openSearch()
        ..search('شريف');

      open.add([sherif, nadia]);
      await pumpEventQueue();

      expect(cubit.state.countOf(JobsTab.upcoming), 1);
      await cubit.close();
    });

    test('regroups once the day changes', () {
      fakeAsync((async) {
        var clock = DateTime(2026, 10, 2, 23, 59);
        final cubit = build(clock: () => clock);
        open.add([sherif]);
        awaiting.add(const []);
        closed.add(const []);
        async.flushMicrotasks();
        expect(cubit.state.countOf(JobsTab.upcoming), 1);

        clock = DateTime(2026, 10, 2, 23, 59, 50);
        async.elapse(const Duration(minutes: 1));
        expect(cubit.state.now, DateTime(2026, 10, 2, 23, 59));

        clock = DateTime(2026, 10, 3, 0, 1);
        async.elapse(const Duration(minutes: 1));

        expect(cubit.state.now, clock);
        expect(cubit.state.upcoming, isEmpty);
        expect(cubit.state.followUp, [
          MissedSection([sherif]),
        ]);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('reports stream errors', () async {
      final observer = ErrorObserver.install();
      final cubit = build();

      open.addError(StateError('boom'));
      await pumpEventQueue();

      expect(observer.errors.single, isA<StateError>());
      expect(cubit.state.isLoading, isTrue);
      await cubit.close();
    });
  });
}
