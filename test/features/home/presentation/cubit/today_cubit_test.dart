import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/home/presentation/cubit/today_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';

import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late StreamController<List<JobSummary>> awaiting;
  late StreamController<bool> hasJobs;
  late Map<DateTime, StreamController<List<JobSummary>>> days;
  late DateTime now;

  setUp(() {
    jobs = MockJobsRepository();
    awaiting = StreamController.broadcast();
    hasJobs = StreamController.broadcast();
    days = {};
    now = DateTime(2026, 10, 2, 11);
    when(() => jobs.watchAwaitingPayment()).thenAnswer((_) => awaiting.stream);
    when(() => jobs.watchHasJobs()).thenAnswer((_) => hasJobs.stream);
    when(
      () => jobs.watchScheduled(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (invocation) => days
          .putIfAbsent(
            invocation.namedArguments[#from] as DateTime,
            StreamController.broadcast,
          )
          .stream,
    );
  });

  TodayCubit build() => TodayCubit(jobs: jobs, clock: () => now)..start();

  JobSummary visit(
    String id,
    int hour, {
    JobStatus status = JobStatus.confirmed,
  }) => testSummary(
    testJob(
      id: id,
      scheduledAt: DateTime(2026, 10, 2, hour),
      status: status,
    ),
  );

  test("watches today's visits from local midnight to the next", () async {
    final cubit = build();

    verify(
      () => jobs.watchScheduled(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 3),
      ),
    ).called(1);
    expect(cubit.state.isLoading, isTrue);

    days[DateTime(2026, 10, 2)]!.add([visit('a', 13)]);
    hasJobs.add(true);
    await pumpEventQueue();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.schedule, [visit('a', 13)]);
    await cubit.close();
  });

  test('a technician with no jobs ever is on their first day', () async {
    final cubit = build();
    days[DateTime(2026, 10, 2)]!.add([]);
    hasJobs.add(false);
    await pumpEventQueue();

    expect(cubit.state.isFirstDay, isTrue);
    await cubit.close();
  });

  group('current visit', () {
    test('is the first one still ahead of the clock', () async {
      final cubit = build();
      days[DateTime(2026, 10, 2)]!.add([
        visit('done', 9, status: JobStatus.finished),
        visit('missed', 9),
        visit('next', 13),
        visit('later', 16),
      ]);
      await pumpEventQueue();

      expect(cubit.state.current?.job.id, 'next');
      await cubit.close();
    });

    test('is the one under way, even if it ran late', () async {
      final cubit = build();
      days[DateTime(2026, 10, 2)]!.add([
        visit('started', 8, status: JobStatus.started),
        visit('next', 13),
      ]);
      await pumpEventQueue();

      expect(cubit.state.current?.job.id, 'started');
      await cubit.close();
    });

    test('includes a visit still within its duration', () async {
      now = DateTime(2026, 10, 2, 13, 30);
      final cubit = build();
      days[DateTime(2026, 10, 2)]!.add([visit('now', 13), visit('next', 16)]);
      await pumpEventQueue();

      expect(cubit.state.current?.job.id, 'now');
      await cubit.close();
    });
  });

  test('sums the money still out and who owes it', () async {
    final cubit = build();
    awaiting.add([
      testSummary(
        testJob(
          id: 'a',
          status: JobStatus.finished,
          finishedAt: DateTime(2026, 9, 20),
        ),
        totalPiastres: 170000,
        paidPiastres: 50000,
      ),
      testSummary(
        testJob(
          id: 'b',
          status: JobStatus.finished,
          finishedAt: DateTime(2026, 9, 30),
        ),
        totalPiastres: 65000,
      ),
      testSummary(
        testJob(
          id: 'c',
          customerId: 'customer-2',
          status: JobStatus.finished,
          finishedAt: DateTime(2026, 10, 2, 9),
        ),
        totalPiastres: 140000,
      ),
    ]);
    await pumpEventQueue();

    expect(cubit.state.owedPiastres, 325000);
    expect(cubit.state.owingCustomers, 2);
    expect(cubit.state.mostDaysLate, 12);
    await cubit.close();
  });

  test('moves on with the clock and to the next day after midnight', () {
    fakeAsync((async) {
      now = DateTime(2026, 10, 2, 23, 59);
      final cubit = build();
      async.flushMicrotasks();

      now = DateTime(2026, 10, 3, 0, 0, 30);
      async.elapse(const Duration(minutes: 1));

      expect(cubit.state.now, now);
      verify(
        () => jobs.watchScheduled(
          from: DateTime(2026, 10, 3),
          to: DateTime(2026, 10, 4),
        ),
      ).called(1);
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });
}
