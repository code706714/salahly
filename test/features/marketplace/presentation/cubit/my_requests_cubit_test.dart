import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  setUp(() => requests = MockConsumerRequestsRepository());

  final waiting = testRequestSummary(id: 'waiting');
  final coming = testRequestSummary(
    id: 'coming',
    status: RequestStatus.assigned,
    offerCount: 3,
    jobStatus: JobStatus.confirmed,
    technicianName: 'محمود السيد',
  );
  final done = testRequestSummary(
    id: 'done',
    status: RequestStatus.assigned,
    offerCount: 2,
    jobStatus: JobStatus.paid,
    technicianName: 'محمود السيد',
    reviewStars: 5,
  );
  final cancelled = testRequestSummary(
    id: 'cancelled',
    status: RequestStatus.cancelled,
    cancelledBy: UserRole.consumer,
  );

  test('splits the requests into in progress and past', () async {
    when(
      requests.fetchRequests,
    ).thenAnswer((_) async => Ok([waiting, coming, done, cancelled]));
    final cubit = MyRequestsCubit(requests);

    await cubit.load();

    expect(cubit.state.status, MyRequestsStatus.ready);
    expect(cubit.state.active, [waiting, coming]);
    expect(cubit.state.past, [done, cancelled]);
    await cubit.close();
  });

  test('fails on the first load, and keeps the list on a later one', () async {
    when(
      requests.fetchRequests,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = MyRequestsCubit(requests);

    await cubit.load();
    expect(cubit.state.status, MyRequestsStatus.failed);

    when(requests.fetchRequests).thenAnswer((_) async => Ok([waiting]));
    await cubit.load();
    when(
      requests.fetchRequests,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await cubit.load();

    expect(cubit.state.status, MyRequestsStatus.ready);
    expect(cubit.state.requests, [waiting]);
    expect(cubit.state.failure, const NetworkFailure());
    await cubit.close();
  });

  test('a load during another fetches again after it', () async {
    final first = Completer<Result<List<RequestSummary>>>();
    when(requests.fetchRequests).thenAnswer((_) => first.future);
    final cubit = MyRequestsCubit(requests);

    final running = cubit.load();
    final again = cubit.load();
    when(requests.fetchRequests).thenAnswer((_) async => Ok([waiting]));
    first.complete(const Ok([]));
    await running;
    await again;

    expect(cubit.state.requests, [waiting]);
    verify(requests.fetchRequests).called(2);
    await cubit.close();
  });
}
