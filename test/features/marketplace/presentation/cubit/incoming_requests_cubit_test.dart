import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';

import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  var now = DateTime(2026, 10, 2, 20);

  setUp(() {
    requests = MockTechnicianRequestsRepository();
    now = DateTime(2026, 10, 2, 20);
  });

  IncomingRequestsCubit cubitFor() =>
      IncomingRequestsCubit(requests, clock: () => now);

  void serve(Result<List<IncomingRequest>> result) =>
      when(requests.fetchNewRequests).thenAnswer((_) async => result);

  final older = testIncoming(
    id: 'older',
    createdAt: DateTime(2026, 10, 2, 18),
  );
  final newer = testIncoming(id: 'newer');

  group('fetching', () {
    test('lists the requests newest first', () async {
      serve(Ok([older, newer]));
      final cubit = cubitFor();
      expect(cubit.state.status, IncomingRequestsStatus.loading);

      await cubit.fetchNewRequests();

      expect(cubit.state.status, IncomingRequestsStatus.ready);
      expect(cubit.state.requests, [newer, older]);
      expect(cubit.state.newRequests, [newer, older]);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('says when the first fetch failed', () async {
      serve(const Err(NetworkFailure()));
      final cubit = cubitFor();

      await cubit.fetchNewRequests();

      expect(cubit.state.status, IncomingRequestsStatus.failed);
      expect(cubit.state.failure, const NetworkFailure());
      await cubit.close();
    });

    test('keeps the list when a refresh fails', () async {
      serve(Ok([newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();

      serve(const Err(NetworkFailure()));
      await cubit.fetchNewRequests();

      expect(cubit.state.status, IncomingRequestsStatus.ready);
      expect(cubit.state.requests, [newer]);
      expect(cubit.state.failure, const NetworkFailure());

      serve(Ok([newer]));
      await cubit.fetchNewRequests();
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('counts only requests still waiting for an offer as new', () async {
      final answered = testIncoming(id: 'answered', myOffer: testMyOffer());
      final dismissed = testIncoming(id: 'dismissed', dismissed: true);
      final full = testIncoming(id: 'full', offerCount: 5);
      final cancelled = testIncoming(
        id: 'cancelled',
        status: RequestStatus.cancelled,
      );
      serve(Ok([newer, answered, dismissed, full, cancelled]));
      final cubit = cubitFor();

      await cubit.fetchNewRequests();

      expect(cubit.state.newRequests, [newer]);
      await cubit.close();
    });
  });

  group('requests the server stops listing', () {
    test('stay, closed, until their time is over', () async {
      serve(Ok([older, newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();

      serve(Ok([newer]));
      await cubit.fetchNewRequests();

      expect(cubit.state.requests, [newer, older]);
      expect(cubit.state.closedIds, {'older'});
      expect(cubit.state.acceptsOffers(older), isFalse);
      expect(cubit.state.newRequests, [newer]);

      now = DateTime(2026, 10, 3, 15);
      await cubit.fetchNewRequests();
      expect(cubit.state.requests, [newer]);
      expect(cubit.state.closedIds, isEmpty);
      await cubit.close();
    });

    test('with an offer sent here stay with it, not closed', () async {
      serve(Ok([newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();
      final offered = testIncoming(id: 'newer', myOffer: testMyOffer());
      cubit.updateRequest(offered);

      serve(const Ok([]));
      await cubit.fetchNewRequests();

      expect(cubit.state.requests, [offered]);
      expect(cubit.state.closedIds, isEmpty);
      expect(cubit.state.newRequests, isEmpty);
      await cubit.close();
    });

    test('an offer sent while the list was on its way is kept', () async {
      serve(Ok([newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();
      final offered = testIncoming(id: 'newer', myOffer: testMyOffer());
      cubit.updateRequest(offered);

      await cubit.fetchNewRequests();

      expect(cubit.state.requests, [offered]);
      await cubit.close();
    });
  });

  group('updating one request', () {
    test('replaces it and forgets it was found closed', () async {
      serve(Ok([older, newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();
      serve(Ok([newer]));
      await cubit.fetchNewRequests();
      final full = testIncoming(
        id: 'older',
        createdAt: DateTime(2026, 10, 2, 18),
        offerCount: 5,
      );

      cubit.updateRequest(full);

      expect(cubit.state.requests, [newer, full]);
      expect(cubit.state.closedIds, isEmpty);
      expect(cubit.state.acceptsOffers(full), isFalse);
      await cubit.close();
    });

    test('takes a dismissed request off the list', () async {
      serve(Ok([older, newer]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();

      cubit.updateRequest(testIncoming(id: 'newer', dismissed: true));

      expect(cubit.state.requests, [older]);
      await cubit.close();
    });

    test('adds a request opened from elsewhere', () async {
      serve(const Ok([]));
      final cubit = cubitFor();
      await cubit.fetchNewRequests();

      cubit.updateRequest(newer);

      expect(cubit.state.requests, [newer]);
      await cubit.close();
    });
  });
}
