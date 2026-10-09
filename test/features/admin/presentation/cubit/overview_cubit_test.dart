import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockOverviewRepository repository;

  setUpAll(AdminHarness.registerFallbacks);

  setUp(() {
    repository = MockOverviewRepository();
    when(
      () => repository.fetchOverview(any()),
    ).thenAnswer((_) async => Ok(testOverview()));
    when(
      () => repository.fetchAreas(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Ok(testCoverage()));
  });

  blocTest<OverviewCubit, OverviewState>(
    'loads the numbers and the coverage of the week',
    build: () => OverviewCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      const OverviewState(),
      OverviewState(
        overview: testOverview(),
        coverage: testCoverage(),
        isLoading: false,
      ),
    ],
    verify: (_) {
      verify(() => repository.fetchOverview(OverviewPeriod.week)).called(1);
      verify(
        () => repository.fetchAreas(
          OverviewPeriod.week,
          limit: OverviewCubit.areaLimit,
          offset: 0,
        ),
      ).called(1);
    },
  );

  blocTest<OverviewCubit, OverviewState>(
    'loads the other period when it is chosen',
    build: () => OverviewCubit(repository),
    act: (cubit) => cubit.selectPeriod(OverviewPeriod.month),
    verify: (cubit) {
      expect(cubit.state.period, OverviewPeriod.month);
      verify(() => repository.fetchOverview(OverviewPeriod.month)).called(1);
    },
  );

  blocTest<OverviewCubit, OverviewState>(
    'does nothing when the period is the same',
    build: () => OverviewCubit(repository),
    act: (cubit) => cubit.selectPeriod(cubit.state.period),
    expect: () => <Object>[],
  );

  blocTest<OverviewCubit, OverviewState>(
    'says why the numbers could not load',
    setUp: () => when(
      () => repository.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => OverviewCubit(repository),
    act: (cubit) => cubit.load(),
    verify: (cubit) {
      expect(cubit.state.failure, const NetworkFailure());
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.overview, isNull);
    },
  );

  test('refreshing keeps the numbers on screen meanwhile', () async {
    final cubit = OverviewCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    final gate = Completer<Result<AdminOverview>>();
    when(() => repository.fetchOverview(any())).thenAnswer((_) => gate.future);

    final refreshing = cubit.refresh();

    expect(cubit.state.overview, testOverview());
    expect(cubit.state.isLoading, isFalse);
    gate.complete(Ok(testOverview(pendingTopups: 6)));
    await refreshing;
    expect(cubit.state.overview?.pendingTopups.count, 6);
  });

  test('a failed refresh keeps the last numbers and says so', () async {
    final cubit = OverviewCubit(repository);
    addTearDown(cubit.close);
    await cubit.load();
    when(
      () => repository.fetchAreas(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await cubit.refresh();

    expect(cubit.state.overview, testOverview());
    expect(cubit.state.failure, const NetworkFailure());
  });

  test('drops the numbers of a period that was left meanwhile', () async {
    final slow = Completer<Result<AdminOverview>>();
    when(
      () => repository.fetchOverview(OverviewPeriod.week),
    ).thenAnswer((_) => slow.future);
    when(
      () => repository.fetchOverview(OverviewPeriod.today),
    ).thenAnswer((_) async => Ok(testOverview(period: OverviewPeriod.today)));
    final cubit = OverviewCubit(repository);
    addTearDown(cubit.close);

    final stale = cubit.load();
    await cubit.selectPeriod(OverviewPeriod.today);
    slow.complete(Ok(testOverview()));
    await stale;

    expect(cubit.state.period, OverviewPeriod.today);
    expect(cubit.state.overview?.period, OverviewPeriod.today);
  });
}
