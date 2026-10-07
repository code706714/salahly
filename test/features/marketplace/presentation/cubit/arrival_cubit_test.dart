import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/arrival_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  final sentAt = DateTime(2026, 10, 3, 11, 50);

  setUp(() => requests = MockTechnicianRequestsRepository());

  ArrivalCubit build() => ArrivalCubit(requests: requests, jobId: 'job-1');

  void findRequest([Result<JobRequestLink?>? result]) =>
      when(
        () => requests.fetchJobRequest('job-1'),
      ).thenAnswer(
        (_) async => result ?? const Ok(JobRequestLink(requestId: 'request-1')),
      );

  void answerSend(Result<DateTime> result) => when(
    () => requests.sendArriving('request-1'),
  ).thenAnswer((_) async => result);

  group('load', () {
    blocTest<ArrivalCubit, ArrivalState>(
      'finds the request',
      setUp: findRequest,
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const ArrivalState(requestId: 'request-1')],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'knows the consumer was told already',
      setUp: () => findRequest(
        Ok(JobRequestLink(requestId: 'request-1', arrivingSentAt: sentAt)),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [ArrivalState(requestId: 'request-1', sentAt: sentAt)],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'stays quiet offline: the button just stays tappable',
      setUp: () => findRequest(const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => <ArrivalState>[],
    );
  });

  group('send', () {
    blocTest<ArrivalCubit, ArrivalState>(
      'tells the consumer',
      setUp: () {
        findRequest();
        answerSend(Ok(sentAt));
      },
      build: build,
      seed: () => const ArrivalState(requestId: 'request-1'),
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(requestId: 'request-1', isSending: true),
        ArrivalState(requestId: 'request-1', sentAt: sentAt),
      ],
      verify: (_) {
        verifyNever(() => requests.fetchJobRequest(any()));
        verify(() => requests.sendArriving('request-1')).called(1);
      },
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'looks the request up first when the page could not',
      setUp: () {
        findRequest();
        answerSend(Ok(sentAt));
      },
      build: build,
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(isSending: true),
        const ArrivalState(requestId: 'request-1', isSending: true),
        ArrivalState(requestId: 'request-1', sentAt: sentAt),
      ],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'says it needs the internet and sends nothing queued',
      setUp: () {
        findRequest(const Err(NetworkFailure()));
      },
      build: build,
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(isSending: true),
        const ArrivalState(isSending: true, failure: NetworkFailure()),
        const ArrivalState(failure: NetworkFailure()),
      ],
      verify: (_) => verifyNever(() => requests.sendArriving(any())),
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'says when the request is not his',
      setUp: () => findRequest(const Ok(null)),
      build: build,
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(isSending: true),
        const ArrivalState(
          isSending: true,
          failure: MarketplaceNotFoundFailure(),
        ),
        const ArrivalState(failure: MarketplaceNotFoundFailure()),
      ],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'keeps the button tappable when the send fails offline',
      setUp: () => answerSend(const Err(NetworkFailure())),
      build: build,
      seed: () => const ArrivalState(requestId: 'request-1'),
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(requestId: 'request-1', isSending: true),
        const ArrivalState(requestId: 'request-1', failure: NetworkFailure()),
      ],
      verify: (cubit) => expect(cubit.state.isSent, isFalse),
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'explains the job is not confirmed on the server yet',
      setUp: () => answerSend(const Err(ArrivalNotReadyFailure())),
      build: build,
      seed: () => const ArrivalState(requestId: 'request-1'),
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(requestId: 'request-1', isSending: true),
        const ArrivalState(
          requestId: 'request-1',
          failure: ArrivalNotReadyFailure(),
        ),
      ],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'forgets an old failure when trying again',
      setUp: () => answerSend(Ok(sentAt)),
      build: build,
      seed: () => const ArrivalState(
        requestId: 'request-1',
        failure: NetworkFailure(),
      ),
      act: (cubit) => cubit.send(),
      expect: () => [
        const ArrivalState(requestId: 'request-1', isSending: true),
        ArrivalState(requestId: 'request-1', sentAt: sentAt),
      ],
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'does nothing once the consumer was told',
      build: build,
      seed: () => ArrivalState(requestId: 'request-1', sentAt: sentAt),
      act: (cubit) => cubit.send(),
      expect: () => <ArrivalState>[],
      verify: (_) => verifyNever(() => requests.sendArriving(any())),
    );

    blocTest<ArrivalCubit, ArrivalState>(
      'does nothing while a send is on its way',
      build: build,
      seed: () => const ArrivalState(requestId: 'request-1', isSending: true),
      act: (cubit) => cubit.send(),
      expect: () => <ArrivalState>[],
      verify: (_) => verifyNever(() => requests.sendArriving(any())),
    );
  });
}
