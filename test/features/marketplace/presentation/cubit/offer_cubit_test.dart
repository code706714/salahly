import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';

import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  var now = DateTime(2026, 10, 2, 20);
  final offer = OfferDraft(
    serviceId: 'ac_inspection_cleaning',
    pricePiastres: 35000,
    arriveAt: DateTime(2026, 10, 3, 12, 30),
    note: 'هجيب معايا الفريون',
  );
  const services = [
    ServicePrice(
      serviceId: 'ac_inspection_cleaning',
      startingPricePiastres: 35000,
    ),
  ];

  setUpAll(() => registerFallbackValue(offer));

  setUp(() {
    requests = MockTechnicianRequestsRepository();
    now = DateTime(2026, 10, 2, 20);
    when(requests.fetchMyServices).thenAnswer((_) async => const Ok(services));
    when(
      () => requests.photoUrl(any()),
    ).thenAnswer(
      (invocation) async =>
          Ok('https://photos/${invocation.positionalArguments.single}'),
    );
  });

  OfferCubit cubitFor() =>
      OfferCubit(requests: requests, requestId: 'request-1', clock: () => now);

  void serve(Result<IncomingRequest?> result) => when(
    () => requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => result);

  group('loading', () {
    test('shows the request, its photos and my services', () async {
      final request = testIncoming(photoPaths: ['a.jpg', 'b.jpg']);
      when(
        () => requests.photoUrl('b.jpg'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      serve(Ok(request));
      final cubit = cubitFor();
      expect(cubit.state.status, OfferLoadStatus.loading);

      await cubit.start();

      expect(cubit.state.status, OfferLoadStatus.ready);
      expect(cubit.state.request, request);
      expect(cubit.state.services, services);
      expect(cubit.state.photoUrls, {'a.jpg': 'https://photos/a.jpg'});
      verify(() => requests.fetchRequest('request-1')).called(1);
      await cubit.close();
    });

    test('links each photo once', () async {
      serve(Ok(testIncoming(photoPaths: ['a.jpg'])));
      final cubit = cubitFor();
      await cubit.start();
      await cubit.fetchRequest();

      verify(() => requests.photoUrl('a.jpg')).called(1);
      await cubit.close();
    });

    test('says when the request was not sent to this technician', () async {
      serve(const Ok(null));
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, OfferLoadStatus.missing);
      await cubit.close();
    });

    test('says when the request could not be fetched', () async {
      serve(const Err(NetworkFailure()));
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, OfferLoadStatus.failed);
      await cubit.close();
    });

    test('keeps the request when a refresh fails', () async {
      final request = testIncoming();
      serve(Ok(request));
      final cubit = cubitFor();
      await cubit.start();

      serve(const Err(NetworkFailure()));
      await cubit.fetchRequest();

      expect(cubit.state.status, OfferLoadStatus.ready);
      expect(cubit.state.request, request);
      await cubit.close();
    });

    test('works without services when they fail to load', () async {
      when(
        requests.fetchMyServices,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      serve(Ok(testIncoming()));
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, OfferLoadStatus.ready);
      expect(cubit.state.services, isEmpty);
      await cubit.close();
    });
  });

  group('arrival times', () {
    Future<List<DateTime>> choicesFor(IncomingRequest request) async {
      serve(Ok(request));
      final cubit = cubitFor();
      await cubit.fetchRequest();
      final choices = cubit.state.arrivalChoices;
      await cubit.close();
      return choices;
    }

    test('every half hour of the window on its day', () async {
      expect(await choicesFor(testIncoming()), [
        DateTime(2026, 10, 3, 12),
        DateTime(2026, 10, 3, 12, 30),
        DateTime(2026, 10, 3, 13),
        DateTime(2026, 10, 3, 13, 30),
        DateTime(2026, 10, 3, 14),
        DateTime(2026, 10, 3, 14, 30),
      ]);
    });

    test('only times not past yet', () async {
      now = DateTime(2026, 10, 3, 13, 10);
      expect(await choicesFor(testIncoming()), [
        DateTime(2026, 10, 3, 13, 30),
        DateTime(2026, 10, 3, 14),
        DateTime(2026, 10, 3, 14, 30),
      ]);

      now = DateTime(2026, 10, 3, 15);
      expect(await choicesFor(testIncoming()), isEmpty);
    });

    test('any time of the day', () async {
      final choices = await choicesFor(
        testIncoming(window: RequestWindow.anyTime),
      );
      expect(choices.first, DateTime(2026, 10, 3, 9));
      expect(choices.last, DateTime(2026, 10, 3, 20, 30));
      expect(choices, hasLength(24));
    });

    test('none before the request is fetched', () {
      expect(OfferState(now: now).arrivalChoices, isEmpty);
    });
  });

  group('sending an offer', () {
    test('sends it and shows it as sent', () async {
      serve(Ok(testIncoming()));
      final sent = testIncoming(offerCount: 3, myOffer: testMyOffer());
      when(() => requests.sendOffer('request-1', offer)).thenAnswer((_) async {
        serve(Ok(sent));
        return const Ok('offer-1');
      });
      final cubit = cubitFor();
      await cubit.start();
      final states = <OfferState>[];
      final listening = cubit.stream.listen(states.add);

      expect(await cubit.sendOffer(offer), isTrue);

      expect(states.first.busy, OfferAction.send);
      expect(cubit.state.busy, isNull);
      expect(cubit.state.failure, isNull);
      expect(cubit.state.request, sent);
      await listening.cancel();
      await cubit.close();
    });

    test('says why it was refused and shows the request as it is', () async {
      serve(Ok(testIncoming()));
      final full = testIncoming(offerCount: 3);
      when(() => requests.sendOffer('request-1', offer)).thenAnswer((_) async {
        serve(Ok(full));
        return const Err(RequestClosedFailure());
      });
      final cubit = cubitFor();
      await cubit.start();

      expect(await cubit.sendOffer(offer), isFalse);

      expect(cubit.state.failure, const RequestClosedFailure());
      expect(cubit.state.busy, isNull);
      expect(cubit.state.request, full);
      await cubit.close();
    });

    test('never sends on a request that takes no offer', () async {
      final cubit = cubitFor();
      expect(await cubit.sendOffer(offer), isFalse);

      serve(Ok(testIncoming(myOffer: testMyOffer())));
      await cubit.start();
      expect(await cubit.sendOffer(offer), isFalse);

      verifyNever(() => requests.sendOffer(any(), any()));
      await cubit.close();
    });

    test('runs one action at a time', () async {
      serve(Ok(testIncoming()));
      final sending = Completer<Result<String>>();
      when(
        () => requests.sendOffer('request-1', offer),
      ).thenAnswer((_) => sending.future);
      final cubit = cubitFor();
      await cubit.start();

      final first = cubit.sendOffer(offer);
      expect(await cubit.sendOffer(offer), isFalse);
      expect(await cubit.dismissRequest(), isFalse);
      sending.complete(const Ok('offer-1'));
      expect(await first, isTrue);

      verify(() => requests.sendOffer('request-1', offer)).called(1);
      verifyNever(() => requests.dismissRequest(any()));
      await cubit.close();
    });
  });

  group('dismissing', () {
    test('takes the request off the new ones', () async {
      serve(Ok(testIncoming()));
      when(() => requests.dismissRequest('request-1')).thenAnswer((_) async {
        serve(Ok(testIncoming(dismissed: true)));
        return const Ok(null);
      });
      final cubit = cubitFor();
      await cubit.start();

      expect(await cubit.dismissRequest(), isTrue);

      expect(cubit.state.request!.dismissed, isTrue);
      expect(cubit.state.busy, isNull);
      await cubit.close();
    });

    test('says why it failed', () async {
      serve(Ok(testIncoming()));
      when(
        () => requests.dismissRequest('request-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = cubitFor();
      await cubit.start();

      expect(await cubit.dismissRequest(), isFalse);

      expect(cubit.state.failure, const NetworkFailure());
      await cubit.close();
    });
  });
}
