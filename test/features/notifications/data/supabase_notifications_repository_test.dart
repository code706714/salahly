import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/notifications/data/repositories/supabase_notifications_repository.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers every call with [body] (JSON), recording requests.
class _Server {
  Object? body;
  int status = 200;
  bool offline = false;
  final requests = <http.Request>[];

  SupabaseNotificationsRepository repository() =>
      SupabaseNotificationsRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'key',
          httpClient: MockClient((request) async {
            if (offline) throw const SocketException('offline');
            requests.add(request);
            return http.Response(
              jsonEncode(body),
              status,
              headers: {
                'content-type': 'application/json; charset=utf-8',
                if (request.method == 'HEAD') 'content-range': '*/7',
              },
              request: request,
            );
          }),
        ),
      );

  http.Request get last => requests.last;
}

void main() {
  late _Server server;

  setUp(() => server = _Server());

  group('fetchNotifications', () {
    test(
      "reads the role's notifications with what their text needs",
      () async {
        server.body = [
          {
            'id': 'n1',
            'kind': 'offer_received',
            'request_id': 'r1',
            'topup_id': null,
            'created_at': '2026-10-06T10:00:00Z',
            'read_at': null,
            'category_id': 'ac',
            'issue': 'not_cooling',
            'area_id': 'nasr_city',
            'preferred_on': '2026-10-08',
            'time_window': 'noon',
            'price_piastres': 35000,
            'arrive_at': '2026-10-08T11:00:00Z',
            'technician_name': 'أحمد رمضان',
            'consumer_name': null,
            'consumer_honorific': null,
            'distance_km': null,
            'topup_uses': null,
          },
          {
            'id': 'n2',
            'kind': 'new_request',
            'request_id': 'r2',
            'created_at': '2026-10-06T09:00:00Z',
            'read_at': '2026-10-06T09:30:00Z',
            'issue': 'leaking',
            'consumer_name': 'نورهان م.',
            'consumer_honorific': 'ms',
            'distance_km': 2.4,
            'time_window': 'any_time',
            'preferred_on': '2026-10-07',
          },
        ];

        final result = await server.repository().fetchNotifications(
          UserRole.consumer,
        );

        final list = (result as Ok<List<AppNotification>>).value;
        expect(list, hasLength(2));
        expect(list[0].kind, NotificationKind.offerReceived);
        expect(list[0].isRead, isFalse);
        expect(list[0].issue, RequestIssue.notCooling);
        expect(list[0].day, DateTime(2026, 10, 8));
        expect(list[0].window, RequestWindow.noon);
        expect(list[0].pricePiastres, 35000);
        expect(list[0].arriveAt, DateTime.utc(2026, 10, 8, 11).toLocal());
        expect(list[0].technicianName, 'أحمد رمضان');
        expect(list[1].kind, NotificationKind.newRequest);
        expect(list[1].isRead, isTrue);
        expect(list[1].consumerHonorific, Honorific.ms);
        expect(list[1].distanceKm, 2.4);
        expect(list[1].window, RequestWindow.anyTime);
        expect(server.last.url.path, '/rest/v1/rpc/my_notifications');
        expect(jsonDecode(server.last.body), {
          'p_role': 'consumer',
          'p_limit': 50,
        });
      },
    );

    test("skips a kind this version doesn't know", () async {
      server.body = [
        {
          'id': 'n1',
          'kind': 'something_new',
          'created_at': '2026-10-06T10:00:00Z',
        },
        {
          'id': 'n2',
          'kind': 'topup_approved',
          'topup_id': 't1',
          'created_at': '2026-10-06T10:00:00Z',
          'topup_uses': 5,
        },
      ];

      final result = await server.repository().fetchNotifications(
        UserRole.technician,
      );

      final list = (result as Ok<List<AppNotification>>).value;
      expect(list.map((n) => n.id), ['n2']);
      expect(list.single.topupUses, 5);
      expect(
        (jsonDecode(server.last.body) as Map<String, dynamic>)['p_role'],
        'technician',
      );
    });

    test('fails with a network failure offline', () async {
      server.offline = true;

      final result = await server.repository().fetchNotifications(
        UserRole.consumer,
      );

      expect((result as Err).failure, const NetworkFailure());
    });

    test('fails with an unexpected failure on a malformed answer', () async {
      server.body = [
        {'id': 'n1', 'kind': 'offer_received'},
      ];

      final result = await server.repository().fetchNotifications(
        UserRole.consumer,
      );

      expect((result as Err).failure, isA<UnexpectedFailure>());
    });
  });

  group('fetchUnreadCount', () {
    test('counts the unread ones of the role', () async {
      final result = await server.repository().fetchUnreadCount(
        UserRole.technician,
      );

      expect((result as Ok<int>).value, 7);
      expect(server.last.method, 'HEAD');
      expect(server.last.url.path, '/rest/v1/notifications');
      expect(server.last.url.queryParameters, {
        'role': 'eq.technician',
        'read_at': 'is.null',
      });
    });

    test('fails offline', () async {
      server.offline = true;

      final result = await server.repository().fetchUnreadCount(
        UserRole.consumer,
      );

      expect((result as Err).failure, const NetworkFailure());
    });
  });

  group('markRead', () {
    test('marks every unread one of the role', () async {
      server.body = 3;

      final result = await server.repository().markRead(UserRole.consumer);

      expect(result, isA<Ok<void>>());
      expect(server.last.url.path, '/rest/v1/rpc/mark_notifications_read');
      expect(jsonDecode(server.last.body), {
        'p_role': 'consumer',
        'p_ids': null,
      });
    });

    test('marks just the ones named', () async {
      server.body = 1;

      await server.repository().markRead(UserRole.technician, ids: ['n1']);

      expect(jsonDecode(server.last.body), {
        'p_role': 'technician',
        'p_ids': ['n1'],
      });
    });

    test('reports a failure', () async {
      server.offline = true;

      final result = await server.repository().markRead(UserRole.consumer);

      expect((result as Err).failure, const NetworkFailure());
    });
  });
}
