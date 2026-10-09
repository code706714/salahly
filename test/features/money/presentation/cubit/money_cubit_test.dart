import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/money/presentation/cubit/money_cubit.dart';

import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late StreamController<List<JobSummary>> awaiting;
  late StreamController<DateTime?> firstFinish;
  late Map<DateTime, StreamController<MonthIncome>> incomes;
  late DateTime now;

  setUp(() {
    jobs = MockJobsRepository();
    awaiting = StreamController.broadcast();
    firstFinish = StreamController.broadcast();
    incomes = {};
    now = DateTime(2026, 10, 2, 11);
    when(() => jobs.watchAwaitingPayment()).thenAnswer((_) => awaiting.stream);
    when(
      () => jobs.watchFirstFinishedAt(),
    ).thenAnswer((_) => firstFinish.stream);
    when(() => jobs.watchMonthIncome(any())).thenAnswer(
      (invocation) => incomes
          .putIfAbsent(
            invocation.positionalArguments.single as DateTime,
            StreamController.broadcast,
          )
          .stream,
    );
  });

  MoneyCubit build() => MoneyCubit(jobs: jobs, clock: () => now)..start();

  const october = MonthIncome(
    jobCount: 27,
    totalPiastres: 1840000,
    collectedPiastres: 1455000,
  );

  JobSummary owed(
    String id, {
    String customerId = 'customer-1',
    DateTime? finishedAt,
    DateTime? promisedOn,
    String? phone = '01228703314',
  }) => testSummary(
    testJob(
      id: id,
      customerId: customerId,
      status: JobStatus.finished,
      finishedAt: finishedAt ?? DateTime(2026, 9, 20),
      paymentPromisedOn: promisedOn,
    ),
    customerPhone: phone,
    totalPiastres: 140000,
  );

  test('opens on the current month and watches its income', () async {
    final cubit = build();

    expect(cubit.state.month, DateTime(2026, 10));
    expect(cubit.state.today, DateTime(2026, 10, 2));
    expect(cubit.state.isCurrentMonth, isTrue);
    expect(cubit.state.income, isNull);
    expect(cubit.state.awaitingPayment, isNull);
    verify(() => jobs.watchMonthIncome(DateTime(2026, 10))).called(1);

    incomes[DateTime(2026, 10)]!.add(october);
    awaiting.add([owed('a')]);
    await pumpEventQueue();

    expect(cubit.state.income, october);
    expect(cubit.state.awaitingPayment, [owed('a')]);
    await cubit.close();
  });

  group('selectMonth', () {
    test('switches to the month picked and forgets the last one', () async {
      final cubit = build();
      incomes[DateTime(2026, 10)]!.add(october);
      await pumpEventQueue();

      cubit.selectMonth(DateTime(2026, 9, 15, 10));

      expect(cubit.state.month, DateTime(2026, 9));
      expect(cubit.state.isCurrentMonth, isFalse);
      expect(cubit.state.income, isNull);
      verify(() => jobs.watchMonthIncome(DateTime(2026, 9))).called(1);
      expect(incomes[DateTime(2026, 10)]!.hasListener, isFalse);

      incomes[DateTime(2026, 9)]!.add(MonthIncome.empty);
      await pumpEventQueue();

      expect(cubit.state.income, MonthIncome.empty);
      await cubit.close();
    });

    test('keeps the month already shown', () async {
      final cubit = build();
      incomes[DateTime(2026, 10)]!.add(october);
      await pumpEventQueue();

      cubit.selectMonth(DateTime(2026, 10, 20));

      expect(cubit.state.income, october);
      verify(() => jobs.watchMonthIncome(any())).called(1);
      await cubit.close();
    });
  });

  group('months', () {
    test('is only the current month before any job is finished', () async {
      final cubit = build();
      expect(cubit.state.months, [DateTime(2026, 10)]);

      firstFinish.add(null);
      await pumpEventQueue();

      expect(cubit.state.months, [DateTime(2026, 10)]);
      await cubit.close();
    });

    test('goes back to the month of the first finished job', () async {
      final cubit = build();
      firstFinish.add(DateTime(2025, 11, 30, 23));
      await pumpEventQueue();

      expect(cubit.state.months, [
        for (var month = 10; month >= -1; month--) DateTime(2026, month),
      ]);
      expect(cubit.state.months.last, DateTime(2025, 11));
      await cubit.close();
    });

    test('ignores a finish dated ahead of the clock', () async {
      final cubit = build();
      firstFinish.add(DateTime(2026, 12, 3));
      await pumpEventQueue();

      expect(cubit.state.months, [DateTime(2026, 10)]);
      await cubit.close();
    });
  });

  group('owed', () {
    test('lists the most late first, then the rest oldest first', () async {
      final cubit = build();
      awaiting.add([
        owed('late-6', finishedAt: DateTime(2026, 9, 26)),
        owed(
          'promised',
          finishedAt: DateTime(2026, 9, 27),
          promisedOn: DateTime(2026, 10, 4),
        ),
        owed('late-12', finishedAt: DateTime(2026, 9, 20)),
        owed('today', finishedAt: DateTime(2026, 10, 2, 9)),
        owed(
          'broken-promise',
          finishedAt: DateTime(2026, 9, 3),
          promisedOn: DateTime(2026, 9, 26),
        ),
      ]);
      await pumpEventQueue();

      final list = cubit.state.owed;
      expect(list.map((job) => job.summary.job.id), [
        'late-12',
        'late-6',
        'broken-promise',
        'promised',
        'today',
      ]);
      expect(list.map((job) => job.due), [
        const PaymentLate(12),
        const PaymentLate(6),
        const PaymentLate(6),
        PaymentPromised(DateTime(2026, 10, 4)),
        const PaymentDueToday(),
      ]);
      await cubit.close();
    });

    test('counts each customer who owes once', () async {
      final cubit = build();
      awaiting.add([
        owed('a'),
        owed('b'),
        owed('c', customerId: 'customer-2'),
      ]);
      await pumpEventQueue();

      expect(cubit.state.owingCustomers, 2);
      await cubit.close();
    });

    test('reminds about money late or promised, to a phone', () async {
      final cubit = build();
      awaiting.add([
        owed('late'),
        owed('promised', promisedOn: DateTime(2026, 10, 3)),
        owed('today', finishedAt: DateTime(2026, 10, 2, 9)),
        owed('no-phone', phone: null),
      ]);
      await pumpEventQueue();

      expect(
        {for (final job in cubit.state.owed) job.summary.job.id: job.canRemind},
        {'late': true, 'promised': true, 'today': false, 'no-phone': false},
      );
      await cubit.close();
    });
  });

  test('moves on to the next day after midnight', () {
    fakeAsync((async) {
      now = DateTime(2026, 10, 2, 23, 59);
      final cubit = build();
      awaiting.add([owed('a', finishedAt: DateTime(2026, 10, 2, 9))]);
      async.flushMicrotasks();
      expect(cubit.state.owed.single.due, const PaymentDueToday());

      now = DateTime(2026, 10, 3, 0, 0, 30);
      async.elapse(const Duration(minutes: 1));

      expect(cubit.state.today, DateTime(2026, 10, 3));
      expect(cubit.state.owed.single.due, const PaymentLate(1));
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  blocTest<MoneyCubit, MoneyState>(
    'reports a list that fails to load',
    build: build,
    act: (_) => awaiting.addError(StateError('database closed')),
    errors: () => [isA<StateError>()],
  );

  blocTest<MoneyCubit, MoneyState>(
    'reports an income that fails to load',
    build: build,
    act: (_) => incomes[DateTime(2026, 10)]!.addError(StateError('closed')),
    errors: () => [isA<StateError>()],
  );

  test('stops watching when closed', () async {
    final cubit = build();
    await cubit.close();

    expect(awaiting.hasListener, isFalse);
    expect(firstFinish.hasListener, isFalse);
    expect(incomes[DateTime(2026, 10)]!.hasListener, isFalse);
  });
}
