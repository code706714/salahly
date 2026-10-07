import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/data/repositories/supabase_technician_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../marketplace_fixtures.dart';

void main() {
  late Object? body;
  late int status;
  late List<http.Request> requests;

  setUp(() {
    body = null;
    status = 200;
    requests = [];
  });

  SupabaseTechnicianRequestsRepository repository() =>
      SupabaseTechnicianRequestsRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json; charset=utf-8'},
              request: request,
            );
          }),
        ),
      );

  test('reads the new requests', () async {
    body = [incomingRequestJson()];

    final result = await repository().fetchNewRequests();

    final request = (result as Ok<List<IncomingRequest>>).value.single;
    expect(requests.single.url.path, '/rest/v1/rpc/technician_requests');
    expect(request.consumerName, 'نورهان م.');
    expect(request.consumerHonorific, Honorific.ms);
    expect(request.distanceKm, 2.0);
    expect(request.day, DateTime(2026, 10, 3));
    expect(request.acceptsOffers, isTrue);
  });

  test("reads a request with this technician's offer", () async {
    body = incomingRequestJson(
      myOffer: {
        'id': 'offer-1',
        'service_id': 'ac_inspection_cleaning',
        'price_piastres': 35000,
        'arrive_at': '2026-10-03T09:00:00+00:00',
        'note': null,
        'status': 'not_chosen',
      },
    );

    final request =
        (await repository().fetchRequest('request-1') as Ok<IncomingRequest?>)
            .value!;

    expect(jsonDecode(requests.single.body), {'p_request_id': 'request-1'});
    expect(request.myOffer?.status, OfferStatus.notChosen);
    expect(request.acceptsOffers, isFalse);
  });

  test('a full request takes no more offers', () {
    expect(
      IncomingRequest(
        id: 'request-1',
        categoryId: 'ac',
        issue: RequestIssue.other,
        areaId: 'nasr_city',
        distanceKm: 1,
        day: _day,
        window: RequestWindow.noon,
        expiresAt: _day,
        createdAt: _day,
        consumerName: 'نورهان م.',
        consumerHonorific: Honorific.ms,
        status: RequestStatus.open,
        sentTo: 5,
        offerCount: IncomingRequest.maxOffers,
        dismissed: false,
      ).acceptsOffers,
      isFalse,
    );
  });

  test('sends an offer', () async {
    body = 'offer-1';

    final result = await repository().sendOffer(
      'request-1',
      OfferDraft(
        serviceId: 'ac_inspection_cleaning',
        pricePiastres: 35000,
        arriveAt: DateTime.utc(2026, 10, 3, 9).toLocal(),
        note: 'السعر شامل الكشف',
      ),
    );

    expect(result, isA<Ok<String>>());
    expect(jsonDecode(requests.single.body), {
      'p_request_id': 'request-1',
      'p_service_id': 'ac_inspection_cleaning',
      'p_price_piastres': 35000,
      'p_arrive_at': '2026-10-03T09:00:00.000Z',
      'p_note': 'السعر شامل الكشف',
    });
  });

  test('says when the technician has no uses left for another offer', () async {
    status = 400;
    body = {'code': 'P0001', 'message': 'no_credits', 'details': null};

    expect(
      await repository().sendOffer(
        'request-1',
        OfferDraft(pricePiastres: 35000, arriveAt: DateTime(2026, 10, 3, 12)),
      ),
      isA<Err<String>>().having(
        (err) => err.failure,
        'failure',
        const NoCreditsFailure(),
      ),
    );
  });

  test("reads the technician's own services and prices", () async {
    body = [
      {'service_id': 'ac_inspection', 'starting_price_piastres': 15000},
    ];

    final result = await repository().fetchMyServices();

    expect(requests.single.url.path, '/rest/v1/technician_services');
    expect(
      requests.single.url.queryParameters['order'],
      'service_id.asc.nullslast',
    );
    expect(
      result,
      isA<Ok<List<ServicePrice>>>().having((ok) => ok.value, 'value', [
        const ServicePrice(
          serviceId: 'ac_inspection',
          startingPricePiastres: 15000,
        ),
      ]),
    );
  });

  group('almost there', () {
    test('finds the request behind a platform job', () async {
      body = {
        'request_id': 'request-1',
        'arriving_sent_at': '2026-10-03T09:00:00+00:00',
      };

      final link =
          (await repository().fetchJobRequest('job-1') as Ok<JobRequestLink?>)
              .value!;

      expect(requests.single.url.path, '/rest/v1/rpc/platform_job_request');
      expect(jsonDecode(requests.single.body), {'p_job_id': 'job-1'});
      expect(link.requestId, 'request-1');
      expect(link.arrivingSentAt, DateTime.utc(2026, 10, 3, 9).toLocal());
    });

    test('finds nothing for a job that is not his', () async {
      body = null;

      expect(
        (await repository().fetchJobRequest('job-1') as Ok<JobRequestLink?>)
            .value,
        isNull,
      );
    });

    test('has no time yet when the consumer was never told', () async {
      body = {'request_id': 'request-1', 'arriving_sent_at': null};

      final link =
          (await repository().fetchJobRequest('job-1') as Ok<JobRequestLink?>)
              .value!;

      expect(link.arrivingSentAt, isNull);
    });

    test('tells the consumer and gets when', () async {
      body = {'status': 'sent', 'sent_at': '2026-10-03T09:00:00+00:00'};

      final result = await repository().sendArriving('request-1');

      expect(requests.single.url.path, '/rest/v1/rpc/technician_arriving');
      expect(jsonDecode(requests.single.body), {'p_request_id': 'request-1'});
      expect(
        (result as Ok<DateTime>).value,
        DateTime.utc(2026, 10, 3, 9).toLocal(),
      );
    });

    test('says the job is not confirmed on the server', () async {
      status = 400;
      body = {'code': 'P0001', 'message': 'not_confirmed', 'details': null};

      expect(
        await repository().sendArriving('request-1'),
        isA<Err<DateTime>>().having(
          (err) => err.failure,
          'failure',
          const ArrivalNotReadyFailure(),
        ),
      );
    });

    test('says the consumer was told often enough', () async {
      status = 400;
      body = {'code': '54000', 'message': 'limit_reached', 'details': null};

      expect(
        await repository().sendArriving('request-1'),
        isA<Err<DateTime>>().having(
          (err) => err.failure,
          'failure',
          const ArrivalLimitFailure(),
        ),
      );
    });

    test('says the request is not his', () async {
      status = 404;
      body = {'code': 'P0002', 'message': 'not_found', 'details': null};

      expect(
        await repository().sendArriving('request-1'),
        isA<Err<DateTime>>().having(
          (err) => err.failure,
          'failure',
          const MarketplaceNotFoundFailure(),
        ),
      );
    });
  });

  test('dismisses a request', () async {
    await repository().dismissRequest('request-1');

    expect(requests.single.url.path, '/rest/v1/rpc/dismiss_request');
  });
}

final _day = DateTime(2026, 10, 3);
