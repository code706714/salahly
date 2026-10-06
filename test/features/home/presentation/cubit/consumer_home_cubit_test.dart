import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/home/presentation/cubit/consumer_home_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  const carpentry = ServiceCategory(
    id: 'carpentry',
    name: 'نجارة',
    isActive: true,
    services: [],
  );

  setUp(() {
    requests = MockConsumerRequestsRepository();
    when(
      () => requests.availableTechnicianCount(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
      ),
    ).thenAnswer((_) async => const Ok(24));
  });

  ConsumerHomeCubit build({String? areaId = 'nasr_city'}) =>
      ConsumerHomeCubit(requests: requests, areaId: areaId);

  void countFor(String categoryId, Result<int> result) => when(
    () => requests.availableTechnicianCount(
      categoryId: categoryId,
      areaId: any(named: 'areaId'),
    ),
  ).thenAnswer((_) async => result);

  test('starts with nothing until the catalog arrives', () async {
    final cubit = build();

    expect(cubit.state, const ConsumerHomeState());
    expect(cubit.state.selected, isNull);
    await cubit.close();
  });

  test('picks the first open category and counts the technicians in the '
      "consumer's area", () async {
    final cubit = build()..useCategories(TestCategories.all);
    await pumpEventQueue();

    expect(cubit.state.categories, TestCategories.all);
    expect(cubit.state.selected, TestCategories.airConditioning);
    expect(cubit.state.technicianCounts, {'ac': 24});
    verify(
      () => requests.availableTechnicianCount(
        categoryId: 'ac',
        areaId: 'nasr_city',
      ),
    ).called(1);
    verifyNoMoreInteractions(requests);
    await cubit.close();
  });

  test('picks only open categories', () async {
    final cubit = build()..useCategories([...TestCategories.all, carpentry]);
    await pumpEventQueue();

    cubit.select('electrical');
    expect(cubit.state.selectedId, 'ac');

    cubit.select('carpentry');
    expect(cubit.state.selected, carpentry);

    cubit.select('unknown');
    expect(cubit.state.selectedId, 'carpentry');
    await cubit.close();
  });

  test('keeps the pick while its category stays open, and counts each '
      'category once', () async {
    final cubit = build()..useCategories([...TestCategories.all, carpentry]);
    await pumpEventQueue();
    cubit
      ..select('carpentry')
      ..useCategories([carpentry, TestCategories.airConditioning]);
    await pumpEventQueue();

    expect(cubit.state.selectedId, 'carpentry');
    verify(
      () => requests.availableTechnicianCount(
        categoryId: 'carpentry',
        areaId: 'nasr_city',
      ),
    ).called(1);

    cubit.useCategories(TestCategories.all);
    expect(cubit.state.selectedId, 'ac');
    await cubit.close();
  });

  test('asks once while a count is on its way', () async {
    final count = Completer<Result<int>>();
    when(
      () => requests.availableTechnicianCount(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
      ),
    ).thenAnswer((_) => count.future);
    final cubit = build()
      ..useCategories(TestCategories.all)
      ..useCategories(TestCategories.all);
    final refreshed = cubit.refresh();
    count.complete(const Ok(3));
    await refreshed;
    await pumpEventQueue();

    expect(cubit.state.technicianCounts, {'ac': 3});
    verify(
      () => requests.availableTechnicianCount(
        categoryId: 'ac',
        areaId: 'nasr_city',
      ),
    ).called(1);
    await cubit.close();
  });

  test('leaves out a count it could not fetch, and refresh tries '
      'again', () async {
    countFor('ac', const Err(NetworkFailure()));
    final cubit = build()..useCategories(TestCategories.all);
    await pumpEventQueue();

    expect(cubit.state.technicianCounts, isEmpty);

    countFor('ac', const Ok(7));
    await cubit.refresh();

    expect(cubit.state.technicianCounts, {'ac': 7});
    await cubit.close();
  });

  test('a failed refresh keeps the last count', () async {
    final cubit = build()..useCategories(TestCategories.all);
    await pumpEventQueue();
    countFor('ac', const Err(NetworkFailure()));

    await cubit.refresh();

    expect(cubit.state.technicianCounts, {'ac': 24});
    await cubit.close();
  });

  test('counts nothing without an area', () async {
    final cubit = build(areaId: null)..useCategories(TestCategories.all);
    await cubit.refresh();

    expect(cubit.state.selectedId, 'ac');
    expect(cubit.state.technicianCounts, isEmpty);
    verifyZeroInteractions(requests);
    await cubit.close();
  });

  test('ignores a count arriving after closing', () async {
    final count = Completer<Result<int>>();
    when(
      () => requests.availableTechnicianCount(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
      ),
    ).thenAnswer((_) => count.future);
    final cubit = build()..useCategories(TestCategories.all);
    await cubit.close();

    count.complete(const Ok(3));
    await pumpEventQueue();

    expect(cubit.state.technicianCounts, isEmpty);
  });
}
