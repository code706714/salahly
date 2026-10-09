import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/data/repositories/supabase_technician_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';
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
        'counter_price_piastres': null,
        'awaiting': 'consumer',
        'revisions_left': 2,
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

  group('browseOpenRequests', () {
    test('asks for a page, for one trade or all', () async {
      body = [incomingRequestJson(), incomingRequestJson(offerCount: 4)];

      final result = await repository().browseOpenRequests(
        categoryId: 'plumbing',
        offset: 20,
      );

      expect(requests.single.url.path, '/rest/v1/rpc/browse_open_requests');
      expect(jsonDecode(requests.single.body), {
        'p_category_id': 'plumbing',
        'p_limit': 20,
        'p_offset': 20,
      });
      final list = (result as Ok<List<IncomingRequest>>).value;
      expect(list.map((request) => request.offerCount), [2, 4]);
    });

    test('is refused for a technician who is not verified', () async {
      status = 403;
      body = {'code': '42501', 'message': 'not_verified'};

      expect(
        await repository().browseOpenRequests(),
        isA<Err<List<IncomingRequest>>>().having(
          (err) => err.failure,
          'failure',
          isA<NotVerifiedFailure>(),
        ),
      );
    });
  });

  group('price talks', () {
    test('lowers the price', () async {
      body = offerStateJson();

      final result = await repository().reviseOffer('offer-1', 30000);

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, '/rest/v1/rpc/revise_offer');
      expect(jsonDecode(requests.single.body), {
        'p_offer_id': 'offer-1',
        'p_price_piastres': 30000,
      });
    });

    test('takes the price the consumer asked for', () async {
      body = 'job-1';

      final result = await repository().acceptCounter('offer-1');

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, '/rest/v1/rpc/accept_counter');
      expect(jsonDecode(requests.single.body), {'p_offer_id': 'offer-1'});
    });

    test('takes the offer back', () async {
      body = offerStateJson(status: 'withdrawn');

      final result = await repository().withdrawOffer('offer-1');

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, '/rest/v1/rpc/withdraw_offer');
      expect(jsonDecode(requests.single.body), {'p_offer_id': 'offer-1'});
    });

    test('names why an answer was refused', () async {
      final failures = {
        'offer_unavailable': const OfferUnavailableFailure(),
        'negotiation_limit': const NegotiationLimitFailure(),
        'no_counter': const NoCounterFailure(),
        'invalid_price': const InvalidPriceFailure(),
        'not_verified': const NotVerifiedFailure(),
        'technician_unavailable': const TechnicianUnavailableFailure(),
      };
      for (final MapEntry(key: message, value: failure) in failures.entries) {
        status = 400;
        body = {'code': 'P0001', 'message': message, 'details': null};
        expect(
          await repository().reviseOffer('offer-1', 30000),
          isA<Err<void>>().having((err) => err.failure, message, failure),
        );
      }
    });

    test('reads the thread of an offer', () async {
      body = offerThreadJson();

      final thread =
          (await repository().fetchOfferThread('offer-1') as Ok<OfferThread?>)
              .value!;

      expect(requests.single.url.path, '/rest/v1/rpc/offer_thread');
      expect(thread.state.status, OfferStatus.sent);
      expect(thread.events, hasLength(3));
    });

    test('has no thread for an offer that is not theirs', () async {
      body = null;

      expect(
        await repository().fetchOfferThread('offer-9'),
        isA<Ok<OfferThread?>>().having((ok) => ok.value, 'value', isNull),
      );
    });

    test("reads the offer's price talk on a request", () async {
      body = incomingRequestJson(
        myOffer: {
          'id': 'offer-1',
          'service_id': null,
          'price_piastres': 35000,
          'arrive_at': '2026-10-03T09:00:00+00:00',
          'note': null,
          'status': 'sent',
          'counter_price_piastres': 30000,
          'awaiting': 'technician',
          'revisions_left': 1,
        },
      );

      final offer =
          (await repository().fetchRequest('request-1') as Ok<IncomingRequest?>)
              .value!
              .myOffer!;

      expect(offer.counterPricePiastres, 30000);
      expect(offer.isCountered, isTrue);
      expect(offer.revisionsLeft, 1);
      expect(offer.reviseRange, (min: 30100, max: 34900));
    });
  });

  group('what the technician offers', () {
    test('reads it', () async {
      body = offeringJson();

      final offering =
          (await repository().fetchOffering() as Ok<TechnicianOffering>).value;

      expect(requests.single.url.path, '/rest/v1/rpc/my_technician_offering');
      expect(offering.workDays, {1, 6, 7});
      expect(offering.radiusKm, 15);
      expect(offering.areaIds, {'heliopolis', 'nasr_city'});
      expect(offering.services.map((service) => service.serviceId), [
        'ac_inspection',
        'plumbing_inspection',
      ]);
      expect(offering.services.last.startingPricePiastres, 15000);
    });

    test('replaces it and says how many open requests it brought', () async {
      body = 3;

      final result = await repository().updateOffering(
        const TechnicianOffering(
          services: [
            ServicePrice(
              serviceId: 'plumbing_inspection',
              startingPricePiastres: 15000,
            ),
          ],
          areaIds: {'nasr_city', 'heliopolis'},
          workDays: {7, 1},
          radiusKm: 10,
        ),
      );

      expect(result, isA<Ok<int>>().having((ok) => ok.value, 'value', 3));
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/update_technician_offering',
      );
      expect(jsonDecode(requests.single.body), {
        'p_services': [
          {
            'service_id': 'plumbing_inspection',
            'starting_price_piastres': 15000,
          },
        ],
        'p_area_ids': ['heliopolis', 'nasr_city'],
        'p_work_days': [1, 7],
        'p_service_radius_km': 10,
      });
    });

    test('is refused when something is not valid', () async {
      status = 400;
      body = {'code': '22023', 'message': 'invalid_services'};

      expect(
        await repository().updateOffering(
          const TechnicianOffering(
            services: [],
            areaIds: {},
            workDays: {},
          ),
        ),
        isA<Err<int>>(),
      );
    });
  });
}

final _day = DateTime(2026, 10, 3);
