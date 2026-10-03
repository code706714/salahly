import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCustomersRepository customers;
  late MockJobsRepository jobs;
  late StreamController<CustomerRecord?> record;
  late StreamController<List<JobSummary>> customerJobs;

  setUpAll(() => registerFallbackValue(const CustomerUnitDraft()));

  setUp(() {
    customers = MockCustomersRepository();
    jobs = MockJobsRepository();
    record = StreamController.broadcast();
    customerJobs = StreamController.broadcast();
    when(
      () => customers.watchCustomer('customer-1'),
    ).thenAnswer((_) => record.stream);
    when(
      () => jobs.watchCustomerJobs('customer-1'),
    ).thenAnswer((_) => customerJobs.stream);
  });

  CustomerCubit build() => CustomerCubit(
    customers: customers,
    jobs: jobs,
    customerId: 'customer-1',
    clock: () => DateTime(2026, 10, 2, 11),
  );

  final karim = CustomerRecord(
    customer: testCustomer(),
    units: [
      testUnit(nextServiceOn: DateTime(2027, 4)),
      testUnit(id: 'unit-2', nextServiceOn: DateTime(2026, 12)),
      testUnit(id: 'unit-3'),
    ],
  );

  JobSummary owed(String id, DateTime finishedAt, int total, int paid) =>
      testSummary(
        Job(
          id: id,
          customerId: 'customer-1',
          status: JobStatus.finished,
          finishedAt: finishedAt,
          createdAt: finishedAt,
          updatedAt: finishedAt,
        ),
        totalPiastres: total,
        paidPiastres: paid,
      );

  final recent = owed('recent', DateTime(2026, 9, 26), 170000, 50000);
  final older = owed('older', DateTime(2026, 7, 12), 65000, 0);
  final paid = testSummary(
    testJob(id: 'paid', status: JobStatus.paid),
    totalPiastres: 110000,
    paidPiastres: 110000,
  );

  test('starts loading on the day it opens', () {
    final state = build().state;

    expect(state.today, DateTime(2026, 10, 2));
    expect(state.isLoading, isTrue);
    expect(state.owedJobs, isEmpty);
    expect(state.nextServiceOn, isNull);
  });

  blocTest<CustomerCubit, CustomerState>(
    'shows the customer once they and their jobs are loaded',
    build: build,
    act: (cubit) async {
      cubit.start();
      record.add(karim);
      await pumpEventQueue();
      customerJobs.add([recent, paid, older]);
    },
    expect: () => [
      isA<CustomerState>()
          .having((state) => state.record, 'record', karim)
          .having((state) => state.isLoading, 'isLoading', isTrue),
      isA<CustomerState>()
          .having((state) => state.jobs, 'jobs', [recent, paid, older])
          .having((state) => state.isLoading, 'isLoading', isFalse),
    ],
  );

  blocTest<CustomerCubit, CustomerState>(
    'is gone once the customer is deleted',
    build: build,
    act: (cubit) async {
      cubit.start();
      record.add(karim);
      await pumpEventQueue();
      record.add(null);
    },
    skip: 1,
    expect: () => [
      isA<CustomerState>()
          .having((state) => state.isGone, 'isGone', isTrue)
          .having((state) => state.isLoading, 'isLoading', isFalse),
    ],
  );

  blocTest<CustomerCubit, CustomerState>(
    'reports errors from the database',
    build: build,
    act: (cubit) {
      cubit.start();
      customerJobs.addError(StateError('db'));
    },
    errors: () => [isA<StateError>()],
  );

  test('sums what is owed, oldest job first', () async {
    final cubit = build()..start();
    record.add(karim);
    customerJobs.add([recent, paid, older]);
    await pumpEventQueue();

    final state = cubit.state;
    expect(state.owedJobs, [older, recent]);
    expect(state.owedPiastres, 65000 + 120000);
    expect(state.owedPaidPiastres, 50000);
    expect(state.owedTotalPiastres, 65000 + 170000);
    await cubit.close();
  });

  test('finds the soonest next service of the units', () async {
    final cubit = build()..start();
    record.add(karim);
    await pumpEventQueue();

    expect(cubit.state.nextServiceOn, DateTime(2026, 12));
    await cubit.close();
  });

  test('stops watching once closed', () async {
    final cubit = build()..start();
    await cubit.close();

    expect(record.hasListener, isFalse);
    expect(customerJobs.hasListener, isFalse);
  });

  group('units', () {
    const draft = CustomerUnitDraft(brand: 'كارير', capacityHp: 2.25);

    test('adds a unit to the customer', () async {
      when(
        () => customers.addUnit(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = build();

      expect(await cubit.saveUnit(draft), isTrue);

      verify(() => customers.addUnit('customer-1', draft)).called(1);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('changes a unit', () async {
      when(
        () => customers.updateUnit(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = build();

      expect(await cubit.saveUnit(draft, unitId: 'unit-2'), isTrue);

      verify(() => customers.updateUnit('unit-2', draft)).called(1);
      await cubit.close();
    });

    test('deletes a unit and adds it back for undo', () async {
      when(
        () => customers.deleteUnit(any()),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => customers.addUnit(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = build();

      expect(await cubit.deleteUnit('unit-1'), isTrue);
      expect(
        await cubit.restoreUnit(testUnit(nextServiceOn: DateTime(2027, 4))),
        isTrue,
      );

      verify(() => customers.deleteUnit('unit-1')).called(1);
      verify(
        () => customers.addUnit(
          'customer-1',
          CustomerUnitDraft(
            brand: 'شارب',
            capacityHp: 1.5,
            room: 'الصالة',
            installedYear: 2021,
            nextServiceOn: DateTime(2027, 4),
          ),
        ),
      ).called(1);
      await cubit.close();
    });

    blocTest<CustomerCubit, CustomerState>(
      'keeps why a change failed until the next one',
      setUp: () {
        when(
          () => customers.deleteUnit(any()),
        ).thenAnswer((_) async => const Err(UnexpectedFailure()));
        when(
          () => customers.addUnit(any(), any()),
        ).thenAnswer((_) async => const Ok(null));
      },
      build: build,
      act: (cubit) async {
        expect(await cubit.deleteUnit('unit-1'), isFalse);
        await cubit.saveUnit(draft);
      },
      expect: () => [
        isA<CustomerState>().having(
          (state) => state.failure,
          'failure',
          const UnexpectedFailure(),
        ),
        isA<CustomerState>().having((state) => state.failure, 'failure', null),
      ],
    );
  });
}
