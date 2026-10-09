import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  const review = ReviewDraft(
    stars: 5,
    tags: {ReviewTag.onTime},
    paidWith: ConsumerPayment.cash,
  );

  setUpAll(() => registerFallbackValue(review));

  setUp(() => requests = MockConsumerRequestsRepository());

  RequestCubit cubitFor({Duration pollEvery = const Duration(seconds: 20)}) =>
      RequestCubit(
        requests: requests,
        requestId: 'request-1',
        pollEvery: pollEvery,
      );

  void serve(RequestDetails? details) => when(
    () => requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => Ok(details));

  group('loading', () {
    test('shows the request', () async {
      final details = testRequestDetails(offers: testOffers());
      serve(details);
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, RequestLoadStatus.ready);
      expect(cubit.state.details, details);
      expect(cubit.state.details!.stage, RequestStage.choosingOffer);
      await cubit.close();
    });

    test("says when the request is not the consumer's or is gone", () async {
      serve(null);
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, RequestLoadStatus.missing);
      await cubit.close();
    });

    test('fails without a request, and keeps one it already has', () async {
      when(
        () => requests.fetchRequest(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = cubitFor();

      await cubit.start();
      expect(cubit.state.status, RequestLoadStatus.failed);

      final details = testRequestDetails();
      serve(details);
      await cubit.refresh();
      when(
        () => requests.fetchRequest(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await cubit.refresh();

      expect(cubit.state.status, RequestLoadStatus.ready);
      expect(cubit.state.details, details);
      await cubit.close();
    });

    test('checks for news while the request is in progress', () {
      fakeAsync((async) {
        serve(testRequestDetails());
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        verify(() => requests.fetchRequest('request-1')).called(1);

        final offered = testRequestDetails(offers: testOffers());
        serve(offered);
        async.elapse(const Duration(seconds: 20));
        expect(cubit.state.details, offered);

        serve(testRequestDetails(job: testRequestJob(status: JobStatus.paid)));
        async.elapse(const Duration(seconds: 20));
        expect(cubit.state.details!.stage, RequestStage.done);

        async.elapse(const Duration(minutes: 5));
        verify(() => requests.fetchRequest('request-1')).called(2);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('stops checking once closed', () {
      fakeAsync((async) {
        serve(testRequestDetails());
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        unawaited(cubit.close());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 1));

        verify(() => requests.fetchRequest('request-1')).called(1);
      });
    });
  });

  group('actions', () {
    test('accepting an offer shows the request assigned', () async {
      serve(testRequestDetails(offers: testOffers()));
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.acceptOffer('offer-2'),
      ).thenAnswer((_) async => const Ok(null));
      final assigned = testRequestDetails(
        job: testRequestJob(status: JobStatus.unconfirmed),
      );
      serve(assigned);

      final states = <RequestState>[];
      final listening = cubit.stream.listen(states.add);
      final accepted = await cubit.acceptOffer('offer-2');
      await listening.cancel();

      expect(accepted, isTrue);
      expect(states.first.busy, RequestAction.acceptOffer);
      expect(
        states.where((s) => s.busy != null).map((s) => s.details!.stage),
        everyElement(isNot(RequestStage.chosen)),
        reason: 'the new request shows only once the action ends',
      );
      expect(cubit.state.busy, isNull);
      expect(cubit.state.details, assigned);
      expect(cubit.state.details!.stage, RequestStage.chosen);
      await cubit.close();
    });

    test(
      'asking for a lower price shows the offers as they are then',
      () async {
        serve(testRequestDetails(offers: testOffers()));
        final cubit = cubitFor();
        await cubit.start();
        when(
          () => requests.counterOffer('offer-1', 30000),
        ).thenAnswer((_) async => const Ok(null));

        final countered = await cubit.counterOffer('offer-1', 30000);

        expect(countered, isTrue);
        verify(() => requests.counterOffer('offer-1', 30000)).called(1);
        expect(cubit.state.busy, isNull);
        await cubit.close();
      },
    );

    test('a refused counter keeps its reason', () async {
      serve(testRequestDetails(offers: testOffers()));
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.counterOffer(any(), any()),
      ).thenAnswer((_) async => const Err(CounterPendingFailure()));

      expect(await cubit.counterOffer('offer-1', 30000), isFalse);

      expect(cubit.state.failure, const CounterPendingFailure());
      await cubit.close();
    });

    test('a refused action keeps its reason and shows the request as it '
        'is now', () async {
      serve(testRequestDetails(offers: testOffers()));
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.acceptOffer(any()),
      ).thenAnswer((_) async => const Err(TechnicianUnavailableFailure()));
      final now = testRequestDetails(offers: testOffers().sublist(1));
      serve(now);

      final accepted = await cubit.acceptOffer('offer-1');

      expect(accepted, isFalse);
      expect(cubit.state.failure, const TechnicianUnavailableFailure());
      expect(cubit.state.details, now);
      await cubit.close();
    });

    test('runs one action at a time', () async {
      serve(testRequestDetails(offers: testOffers()));
      final cubit = cubitFor();
      await cubit.start();
      final accepting = Completer<Result<void>>();
      when(
        () => requests.acceptOffer(any()),
      ).thenAnswer((_) => accepting.future);

      final first = cubit.acceptOffer('offer-2');
      final second = await cubit.cancel();
      accepting.complete(const Ok(null));

      expect(await first, isTrue);
      expect(second, isFalse);
      verifyNever(() => requests.cancelRequest(any()));
      await cubit.close();
    });

    test('a new action clears the last failure', () async {
      serve(testRequestDetails());
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.widenRequestWindow('request-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await cubit.widenWindow();
      expect(cubit.state.failure, const NetworkFailure());

      when(
        () => requests.cancelRequest('request-1'),
      ).thenAnswer((_) async => const Ok(null));
      expect(await cubit.cancel(), isTrue);

      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('a refresh running when an action ends is followed by a fresh '
        'one', () async {
      serve(testRequestDetails(offers: testOffers()));
      final cubit = cubitFor();
      await cubit.start();

      final stale = Completer<Result<RequestDetails?>>();
      when(
        () => requests.fetchRequest('request-1'),
      ).thenAnswer((_) => stale.future);
      final polling = cubit.refresh();
      when(
        () => requests.acceptOffer('offer-2'),
      ).thenAnswer((_) async => const Ok(null));
      final assigned = testRequestDetails(job: testRequestJob());
      final accepting = cubit.acceptOffer('offer-2');
      await Future<void>.delayed(Duration.zero);
      serve(assigned);
      stale.complete(Ok(testRequestDetails(offers: testOffers())));

      await polling;
      expect(await accepting, isTrue);
      expect(cubit.state.details, assigned);
      await cubit.close();
    });

    test('answers the price change it was shown', () async {
      final sentAt = DateTime(2026, 10, 3, 12, 35);
      serve(testRequestDetails(job: testPriceChangeJob()));
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.answerPriceChange(
          'request-1',
          quoteSentAt: sentAt,
          approve: false,
        ),
      ).thenAnswer((_) async => const Ok(null));

      expect(await cubit.answerPriceChange(approve: false), isTrue);

      verify(
        () => requests.answerPriceChange(
          'request-1',
          quoteSentAt: sentAt,
          approve: false,
        ),
      ).called(1);
      await cubit.close();
    });

    test('does nothing when no price change waits', () async {
      serve(testRequestDetails(job: testRequestJob()));
      final cubit = cubitFor();
      await cubit.start();

      expect(await cubit.answerPriceChange(approve: true), isFalse);

      verifyNever(
        () => requests.answerPriceChange(
          any(),
          quoteSentAt: any(named: 'quoteSentAt'),
          approve: any(named: 'approve'),
        ),
      );
      await cubit.close();
    });

    test('sends the review', () async {
      serve(testRequestDetails(job: testRequestJob(status: JobStatus.paid)));
      final cubit = cubitFor();
      await cubit.start();
      when(
        () => requests.submitReview('request-1', review),
      ).thenAnswer((_) async => const Ok(null));

      expect(await cubit.submitReview(review), isTrue);

      verify(() => requests.submitReview('request-1', review)).called(1);
      await cubit.close();
    });
  });
}
