import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_directory_cubit.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  setUpAll(() => registerFallbackValue(TechnicianSort.rating));

  setUp(() => requests = MockConsumerRequestsRepository());

  void serve(
    List<TechnicianListing> page, {
    String? categoryId,
    String? areaId,
    TechnicianSort sort = TechnicianSort.rating,
    int offset = 0,
  }) => when(
    () => requests.browseTechnicians(
      categoryId: categoryId,
      areaId: areaId,
      sort: sort,
      offset: offset,
    ),
  ).thenAnswer((_) async => Ok(page));

  List<TechnicianListing> fullPage() => [
    for (var i = 0; i < technicianPageSize; i++) testListing(id: 'tech-$i'),
  ];

  test('starts loading', () {
    expect(
      TechnicianDirectoryCubit(requests).state.status,
      TechnicianDirectoryStatus.loading,
    );
  });

  test('shows the first page, rated first', () async {
    serve([testListing()]);
    final cubit = TechnicianDirectoryCubit(requests);

    await cubit.load();

    expect(cubit.state.status, TechnicianDirectoryStatus.ready);
    expect(cubit.state.technicians, [testListing()]);
    expect(cubit.state.sort, TechnicianSort.rating);
    expect(cubit.state.hasMore, isFalse);
    await cubit.close();
  });

  test('fails, then loads again', () async {
    when(
      () => requests.browseTechnicians(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
        sort: any(named: 'sort'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = TechnicianDirectoryCubit(requests);

    await cubit.load();
    expect(cubit.state.status, TechnicianDirectoryStatus.failed);
    expect(cubit.state.failure, const NetworkFailure());

    serve([testListing()]);
    await cubit.load();

    expect(cubit.state.status, TechnicianDirectoryStatus.ready);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('keeps the list when a refresh fails', () async {
    serve([testListing()]);
    final cubit = TechnicianDirectoryCubit(requests);
    await cubit.load();
    when(
      () => requests.browseTechnicians(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
        sort: any(named: 'sort'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await cubit.load();

    expect(cubit.state.status, TechnicianDirectoryStatus.ready);
    expect(cubit.state.technicians, hasLength(1));
    expect(cubit.state.failure, const NetworkFailure());
    await cubit.close();
  });

  test('filters by trade, area and order, each from the first page', () async {
    serve([testListing()]);
    serve(
      [testListing(id: 'tech-2')],
      categoryId: 'plumbing',
    );
    serve(
      [testListing(id: 'tech-3')],
      categoryId: 'plumbing',
      areaId: 'nasr_city',
    );
    serve(
      [testListing(id: 'tech-4')],
      categoryId: 'plumbing',
      areaId: 'nasr_city',
      sort: TechnicianSort.price,
    );
    final cubit = TechnicianDirectoryCubit(requests);
    await cubit.load();

    await cubit.selectCategory('plumbing');
    expect(cubit.state.technicians.single.card.id, 'tech-2');

    await cubit.selectArea('nasr_city');
    expect(cubit.state.technicians.single.card.id, 'tech-3');

    await cubit.selectSort(TechnicianSort.price);
    expect(cubit.state.technicians.single.card.id, 'tech-4');
    expect(cubit.state.categoryId, 'plumbing');
    expect(cubit.state.areaId, 'nasr_city');

    serve(
      [testListing(id: 'tech-5')],
      areaId: 'nasr_city',
      sort: TechnicianSort.price,
    );
    await cubit.selectCategory(null);
    expect(cubit.state.technicians.single.card.id, 'tech-5');
    serve([testListing(id: 'tech-6')], sort: TechnicianSort.price);
    await cubit.selectArea(null);
    expect(cubit.state.technicians.single.card.id, 'tech-6');
    await cubit.close();
  });

  test('adds the next page while the last one was full', () async {
    serve(fullPage());
    serve([testListing(id: 'tech-last')], offset: technicianPageSize);
    final cubit = TechnicianDirectoryCubit(requests);
    await cubit.load();
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();

    expect(cubit.state.technicians, hasLength(technicianPageSize + 1));
    expect(cubit.state.technicians.last.card.id, 'tech-last');
    expect(cubit.state.hasMore, isFalse);
    expect(cubit.state.loadingMore, isFalse);

    await cubit.loadMore();
    verify(
      () => requests.browseTechnicians(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
        sort: any(named: 'sort'),
        offset: technicianPageSize,
      ),
    ).called(1);
    await cubit.close();
  });

  test('keeps the list when the next page fails', () async {
    serve(fullPage());
    when(
      () => requests.browseTechnicians(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
        sort: any(named: 'sort'),
        offset: technicianPageSize,
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = TechnicianDirectoryCubit(requests);
    await cubit.load();

    await cubit.loadMore();

    expect(cubit.state.technicians, hasLength(technicianPageSize));
    expect(cubit.state.hasMore, isTrue);
    expect(cubit.state.loadingMore, isFalse);
    expect(cubit.state.failure, const NetworkFailure());
    await cubit.close();
  });

  test('drops the answer to a filter that was changed meanwhile', () async {
    final slow = Completer<Result<List<TechnicianListing>>>();
    when(
      () => requests.browseTechnicians(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
        sort: any(named: 'sort'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => slow.future);
    final cubit = TechnicianDirectoryCubit(requests);
    final first = cubit.load();

    serve([testListing(id: 'tech-2')], categoryId: 'ac');
    await cubit.selectCategory('ac');
    slow.complete(Ok([testListing(id: 'old')]));
    await first;

    expect(cubit.state.technicians.single.card.id, 'tech-2');
    await cubit.close();
  });
}
