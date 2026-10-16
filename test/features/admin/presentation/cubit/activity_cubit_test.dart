import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/cubit/activity_cubit.dart';

import '../../../../helpers/activity_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockActivityRepository repository;

  setUpAll(AdminHarness.registerFallbacks);

  setUp(() {
    repository = MockActivityRepository();
    when(
      () => repository.fetchMoney(any()),
    ).thenAnswer((_) async => Ok(testMoney()));
    when(
      () => repository.fetchTechnicians(any()),
    ).thenAnswer((_) async => Ok(testActivityReport()));
  });

  blocTest<ActivityCubit, ActivityState>(
    'loads the money and the technicians of today',
    build: () => ActivityCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      const ActivityState(),
      ActivityState(
        money: testMoney(),
        report: testActivityReport(),
        isLoading: false,
      ),
    ],
    verify: (_) {
      verify(() => repository.fetchMoney(OverviewPeriod.today)).called(1);
      verify(() => repository.fetchTechnicians(OverviewPeriod.today)).called(1);
    },
  );

  blocTest<ActivityCubit, ActivityState>(
    'loads the other period when it is chosen',
    build: () => ActivityCubit(repository),
    act: (cubit) => cubit.selectPeriod(OverviewPeriod.month),
    verify: (cubit) {
      expect(cubit.state.period, OverviewPeriod.month);
      verify(() => repository.fetchMoney(OverviewPeriod.month)).called(1);
      verify(
        () => repository.fetchTechnicians(OverviewPeriod.month),
      ).called(1);
    },
  );

  blocTest<ActivityCubit, ActivityState>(
    'does nothing when the period is the same',
    build: () => ActivityCubit(repository),
    act: (cubit) => cubit.selectPeriod(cubit.state.period),
    expect: () => <Object>[],
  );

  blocTest<ActivityCubit, ActivityState>(
    'says why the numbers could not load',
    setUp: () => when(
      () => repository.fetchTechnicians(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => ActivityCubit(repository),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.failure, const NetworkFailure());
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.money, isNull);
    },
  );
}
