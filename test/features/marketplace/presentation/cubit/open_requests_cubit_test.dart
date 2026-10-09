import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/cubit/open_requests_cubit.dart';

import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;

  setUp(() => requests = MockTechnicianRequestsRepository());

  void serve(
    List<IncomingRequest> page, {
    String? categoryId,
    int offset = 0,
  }) => when(
    () => requests.browseOpenRequests(
      categoryId: categoryId,
      offset: offset,
    ),
  ).thenAnswer((_) async => Ok(page));

  void fail(Failure failure) => when(
    () => requests.browseOpenRequests(
      categoryId: any(named: 'categoryId'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => Err(failure));

  List<IncomingRequest> fullPage() => [
    for (var i = 0; i < openRequestsPageSize; i++) testIncoming(id: 'r-$i'),
  ];

  test('starts loading', () {
    expect(
      OpenRequestsCubit(requests).state.status,
      OpenRequestsStatus.loading,
    );
  });

  test('shows the first page', () async {
    serve([testIncoming()]);
    final cubit = OpenRequestsCubit(requests);

    await cubit.load();

    expect(cubit.state.status, OpenRequestsStatus.ready);
    expect(cubit.state.requests, [testIncoming()]);
    expect(cubit.state.hasMore, isFalse);
    await cubit.close();
  });

  test('fails, then loads again', () async {
    fail(const NetworkFailure());
    final cubit = OpenRequestsCubit(requests);

    await cubit.load();
    expect(cubit.state.status, OpenRequestsStatus.failed);
    expect(cubit.state.failure, const NetworkFailure());

    serve([testIncoming()]);
    await cubit.load();

    expect(cubit.state.status, OpenRequestsStatus.ready);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('says when the technician is not verified', () async {
    fail(const NotVerifiedFailure());
    final cubit = OpenRequestsCubit(requests);

    await cubit.load();

    expect(cubit.state.status, OpenRequestsStatus.failed);
    expect(cubit.state.failure, const NotVerifiedFailure());
    await cubit.close();
  });

  test('keeps the list when a refresh fails', () async {
    serve([testIncoming()]);
    final cubit = OpenRequestsCubit(requests);
    await cubit.load();
    fail(const NetworkFailure());

    await cubit.load();

    expect(cubit.state.status, OpenRequestsStatus.ready);
    expect(cubit.state.requests, hasLength(1));
    expect(cubit.state.failure, const NetworkFailure());
    await cubit.close();
  });

  test('shows one trade, then all of them', () async {
    serve([testIncoming()]);
    serve([testIncoming(id: 'plumbing-1')], categoryId: 'plumbing');
    final cubit = OpenRequestsCubit(requests);
    await cubit.load();

    await cubit.selectCategory('plumbing');
    expect(cubit.state.categoryId, 'plumbing');
    expect(cubit.state.requests.single.id, 'plumbing-1');

    await cubit.selectCategory(null);
    expect(cubit.state.categoryId, isNull);
    expect(cubit.state.requests.single.id, 'request-1');
    await cubit.close();
  });

  test('adds the next page while the last one was full', () async {
    serve(fullPage());
    serve([testIncoming(id: 'last')], offset: openRequestsPageSize);
    final cubit = OpenRequestsCubit(requests);
    await cubit.load();
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();

    expect(cubit.state.requests, hasLength(openRequestsPageSize + 1));
    expect(cubit.state.requests.last.id, 'last');
    expect(cubit.state.hasMore, isFalse);

    await cubit.loadMore();
    verify(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: openRequestsPageSize,
      ),
    ).called(1);
    await cubit.close();
  });

  test('keeps the list when the next page fails', () async {
    serve(fullPage());
    final cubit = OpenRequestsCubit(requests);
    await cubit.load();
    when(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: openRequestsPageSize,
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await cubit.loadMore();

    expect(cubit.state.requests, hasLength(openRequestsPageSize));
    expect(cubit.state.hasMore, isTrue);
    expect(cubit.state.loadingMore, isFalse);
    expect(cubit.state.failure, const NetworkFailure());
    await cubit.close();
  });

  test('drops the answer to a trade that was changed meanwhile', () async {
    final slow = Completer<Result<List<IncomingRequest>>>();
    when(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => slow.future);
    final cubit = OpenRequestsCubit(requests);
    final first = cubit.load();

    serve([testIncoming(id: 'plumbing-1')], categoryId: 'plumbing');
    await cubit.selectCategory('plumbing');
    slow.complete(Ok([testIncoming(id: 'old')]));
    await first;

    expect(cubit.state.requests.single.id, 'plumbing-1');
    await cubit.close();
  });
}
