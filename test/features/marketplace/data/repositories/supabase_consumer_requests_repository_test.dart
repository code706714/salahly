import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/data/repositories/supabase_consumer_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../marketplace_fixtures.dart';

/// Answers every call with [body] (JSON) and [status], recording requests.
class _Server {
  Object? body;
  int status = 200;
  bool offline = false;
  final requests = <http.Request>[];

  SupabaseConsumerRequestsRepository repository() =>
      SupabaseConsumerRequestsRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            if (offline) throw const SocketException('offline');
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

  String get lastPath => requests.last.url.path;

  Map<String, dynamic> get lastParams =>
      jsonDecode(requests.last.body) as Map<String, dynamic>;

  void fails(String message) {
    status = 400;
    body = {'code': 'P0001', 'message': message, 'details': null};
  }
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  group('sendRequest', () {
    test("sends the draft in the server's terms", () async {
      server.body = {'id': 'request-1', 'sent_to': 5};

      final result = await server.repository().sendRequest(
        RequestDraft(
          categoryId: 'ac',
          issue: RequestIssue.needsCleaning,
          description: 'شارب 1.5 حصان',
          photoPaths: const ['user-1/photo-1.jpg'],
          addressId: 'address-1',
          day: DateTime(2026, 10, 3),
          window: RequestWindow.noon,
        ),
      );

      expect(
        result,
        isA<Ok<SentRequest>>().having(
          (ok) => ok.value,
          'value',
          const SentRequest(id: 'request-1', sentTo: 5),
        ),
      );
      expect(server.lastPath, '/rest/v1/rpc/create_service_request');
      expect(server.lastParams, {
        'p_category_id': 'ac',
        'p_issue': 'needs_cleaning',
        'p_description': 'شارب 1.5 حصان',
        'p_photo_paths': ['user-1/photo-1.jpg'],
        'p_address_id': 'address-1',
        'p_preferred_on': '2026-10-03',
        'p_window': 'noon',
        'p_technician_id': null,
      });
    });

    test('says when the consumer has no uses left', () async {
      server.fails('no_credits');

      final result = await server.repository().sendRequest(
        RequestDraft(
          categoryId: 'ac',
          issue: RequestIssue.other,
          addressId: 'address-1',
          day: DateTime(2026, 10, 3),
          window: RequestWindow.evening,
        ),
      );

      expect(
        result,
        isA<Err<SentRequest>>().having(
          (err) => err.failure,
          'failure',
          const NoCreditsFailure(),
        ),
      );
    });
  });

  group('fetchRequest', () {
    test('reads the request, its offers and the job', () async {
      server.body = requestDetailsJson(job: requestJobJson());

      final result = await server.repository().fetchRequest('request-1');

      final details = (result as Ok<RequestDetails?>).value!;
      expect(server.lastParams, {'p_request_id': 'request-1'});
      expect(details.issue, RequestIssue.notCooling);
      expect(details.day, DateTime(2026, 10, 3));
      expect(details.window, RequestWindow.noon);
      expect(details.status, RequestStatus.assigned);
      expect(details.stage, RequestStage.confirmed);
      expect(details.chosenOffer?.technician.name, 'محمود السيد');
      expect(details.chosenOffer?.distanceKm, 2.4);
      expect(
        details.chosenOffer?.arriveAt.toUtc(),
        DateTime.utc(2026, 10, 3, 9),
      );
      expect(details.technicianPhone, '+201009990041');
      expect(details.job?.items.map((line) => line.addedLater), [false, true]);
      expect(details.job?.totalPiastres, 65000);
      expect(
        details.job?.quoteSentAt?.toUtc(),
        DateTime.utc(2026, 10, 3, 9, 35, 0, 123, 456),
      );
      expect(details.hasPendingPriceChange, isTrue);
      expect(details.review, isNull);
    });

    test('reads a rated request', () async {
      server.body = requestDetailsJson(
        job: requestJobJson(status: 'paid', quoteStatus: 'accepted'),
        review: {
          'stars': 5,
          'tags': ['on_time', 'clean_work'],
          'comment': null,
          'paid_with': 'not_yet',
          'created_at': '2026-10-03T12:00:00+00:00',
        },
      );

      final details =
          (await server.repository().fetchRequest('request-1')
                  as Ok<RequestDetails?>)
              .value!;

      expect(details.stage, RequestStage.done);
      expect(details.hasPendingPriceChange, isFalse);
      expect(details.review?.tags, {ReviewTag.onTime, ReviewTag.cleanWork});
      expect(details.review?.paidWith, ConsumerPayment.notYet);
    });

    test("is null for a request that isn't the consumer's", () async {
      server.body = null;

      expect(
        await server.repository().fetchRequest('request-1'),
        isA<Ok<RequestDetails?>>().having((ok) => ok.value, 'value', isNull),
      );
    });

    test('reports a network failure offline', () async {
      server.offline = true;

      expect(
        await server.repository().fetchRequest('request-1'),
        isA<Err<RequestDetails?>>().having(
          (err) => err.failure,
          'failure',
          const NetworkFailure(),
        ),
      );
    });
  });

  test("reads the list with each request's stage", () async {
    server.body = [
      {
        'id': 'request-2',
        'category_id': 'ac',
        'issue': 'leaking',
        'description': null,
        'status': 'open',
        'cancelled_by': null,
        'preferred_on': '2026-10-04',
        'time_window': 'afternoon',
        'created_at': '2026-10-02T16:40:00+00:00',
        'offer_count': 0,
        'technician': null,
        'price_piastres': null,
        'arrive_at': null,
        'job_status': null,
        'scheduled_at': null,
        'review_stars': null,
      },
      {
        'id': 'request-1',
        'category_id': 'ac',
        'issue': 'not_cooling',
        'description': null,
        'status': 'cancelled',
        'cancelled_by': 'technician',
        'preferred_on': '2026-10-03',
        'time_window': 'noon',
        'created_at': '2026-10-01T16:40:00+00:00',
        'offer_count': 2,
        'technician': {'id': 'tech-1', 'name': 'محمود السيد'},
        'price_piastres': 35000,
        'arrive_at': '2026-10-03T09:00:00+00:00',
        'job_status': 'cancelled',
        'scheduled_at': '2026-10-03T09:00:00+00:00',
        'review_stars': null,
      },
    ];

    final requests =
        (await server.repository().fetchRequests() as Ok<List<RequestSummary>>)
            .value;

    expect(server.lastPath, '/rest/v1/rpc/my_requests');
    expect(requests.map((request) => request.stage), [
      RequestStage.waitingForOffers,
      RequestStage.cancelled,
    ]);
    expect(requests.last.cancelledBy, UserRole.technician);
    expect(requests.last.technicianName, 'محمود السيد');
    expect(requests.last.jobStatus, JobStatus.cancelled);
  });

  test("reads a technician's page", () async {
    server.body = {
      ...technicianCardJson(),
      'on_time_percent': 98,
      'area_ids': ['heliopolis', 'nasr_city'],
      'services': [
        {
          'service_id': 'ac_inspection_cleaning',
          'starting_price_piastres': 35000,
        },
      ],
      'reviews': [
        {
          'author': 'دعاء م.',
          'stars': 5,
          'comment': 'جه في معاده بالظبط',
          'tags': ['on_time'],
          'issue': 'needs_cleaning',
          'created_at': '2026-09-20T12:00:00+00:00',
        },
      ],
    };

    final profile =
        (await server.repository().fetchTechnician('tech-1')
                as Ok<TechnicianPublicProfile?>)
            .value!;

    expect(server.lastParams, {'p_technician_id': 'tech-1'});
    expect(profile.card.rating, 4.8);
    expect(profile.card.jobsDone, 214);
    expect(profile.onTimePercent, 98);
    expect(profile.services.single.startingPricePiastres, 35000);
    expect(profile.reviews.single.author, 'دعاء م.');
    expect(profile.reviews.single.issue, RequestIssue.needsCleaning);
  });

  group('answers', () {
    test('a price change, naming it by when it was sent', () async {
      await server.repository().answerPriceChange(
        'request-1',
        quoteSentAt: DateTime.utc(2026, 10, 3, 9, 35, 0, 123, 456).toLocal(),
        approve: false,
      );

      expect(server.lastPath, '/rest/v1/rpc/answer_price_change');
      expect(server.lastParams, {
        'p_request_id': 'request-1',
        'p_quote_sent_at': '2026-10-03T09:35:00.123456Z',
        'p_approve': false,
      });
    });

    test("a rating, in the server's terms", () async {
      await server.repository().submitReview(
        'request-1',
        const ReviewDraft(
          stars: 4,
          tags: {ReviewTag.fairPrice},
          comment: 'محترم',
          paidWith: ConsumerPayment.instapay,
        ),
      );

      expect(server.lastParams, {
        'p_request_id': 'request-1',
        'p_stars': 4,
        'p_tags': ['fair_price'],
        'p_comment': 'محترم',
        'p_paid_with': 'instapay',
      });
    });

    test('a complaint', () async {
      await server.repository().submitComplaint(
        'request-1',
        const ComplaintDraft(reason: ComplaintReason.priceRaised),
      );

      expect(server.lastParams, {
        'p_request_id': 'request-1',
        'p_reason': 'price_raised',
        'p_details': null,
        'p_photo_path': null,
      });
    });
  });

  test('names the failures the server raises', () async {
    final failures = {
      'request_closed': const RequestClosedFailure(),
      'technician_unavailable': const TechnicianUnavailableFailure(),
      'offer_expired': const OfferExpiredFailure(),
      'too_late': const TooLateToCancelFailure(),
      'no_price_change': const PriceChangeGoneFailure(),
      'already_reviewed': const AlreadySentFailure(),
      'limit_reached': const AddressLimitFailure(),
      'not_found': const MarketplaceNotFoundFailure(),
    };
    for (final MapEntry(key: message, value: failure) in failures.entries) {
      server.fails(message);
      expect(
        await server.repository().acceptOffer('offer-1'),
        isA<Err<void>>().having((err) => err.failure, message, failure),
      );
    }
  });

  test('reads the address book and saves an address', () async {
    server.body = [
      {
        'id': 'address-1',
        'label': 'البيت',
        'area_id': 'nasr_city',
        'details': '14 شارع عباس العقاد',
      },
    ];
    final addresses = await server.repository().fetchAddresses();
    expect(
      addresses,
      isA<Ok<Object>>().having(
        (ok) => ok.value,
        'value',
        hasLength(1),
      ),
    );
    expect(server.requests.last.url.path, '/rest/v1/consumer_addresses');

    server.body = 'address-2';
    expect(
      await server.repository().saveAddress(
        const ConsumerAddressDraft(
          label: 'بيت ماما',
          areaId: 'heliopolis',
          details: 'شارع النزهة',
        ),
      ),
      isA<Ok<String>>().having((ok) => ok.value, 'value', 'address-2'),
    );
    expect(server.lastParams, {
      'p_id': null,
      'p_label': 'بيت ماما',
      'p_area_id': 'heliopolis',
      'p_details': 'شارع النزهة',
    });
  });
}
