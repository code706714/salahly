import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/data/repositories/supabase_balance_repository.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/balance_fixtures.dart';

/// Answers every call with [body] (JSON) and [status], recording requests.
class _Server {
  Object? body;
  int status = 200;
  bool offline = false;
  final requests = <http.Request>[];

  SupabaseBalanceRepository repository() => SupabaseBalanceRepository(
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

  http.Request get last => requests.last;

  Map<String, dynamic> get lastParams =>
      jsonDecode(last.body) as Map<String, dynamic>;

  void fails(String message) {
    status = 400;
    body = {'code': 'P0001', 'message': message, 'details': null};
  }
}

Matcher _failure(Failure failure) =>
    isA<Err<Object?>>().having((err) => err.failure, 'failure', failure);

void main() {
  late _Server server;

  setUp(() => server = _Server());

  group('fetchPacks', () {
    test('reads the packs on sale to the role, in order', () async {
      server.body = [
        {'id': 'pack-1', 'uses': 1, 'price_piastres': 2000},
        {'id': 'pack-5', 'uses': 5, 'price_piastres': 8000},
      ];

      final result = await server.repository().fetchPacks(UserRole.consumer);

      expect(result, isA<Ok<Object?>>());
      expect((result as Ok).value, consumerPacks);
      expect(server.last.url.path, '/rest/v1/credit_packs');
      expect(server.last.url.queryParameters, {
        'select': 'id,uses,price_piastres',
        'role': 'eq.consumer',
        'order': 'sort_order.asc.nullslast,uses.asc.nullslast',
      });
    });

    test('asks for the technician packs of a technician', () async {
      server.body = <Object>[];

      await server.repository().fetchPacks(UserRole.technician);

      expect(server.last.url.queryParameters['role'], 'eq.technician');
    });

    test('reports a network failure offline', () async {
      server.offline = true;

      expect(
        await server.repository().fetchPacks(UserRole.consumer),
        _failure(const NetworkFailure()),
      );
    });
  });

  test('fetchPaymentAccounts reads where to transfer', () async {
    server.body = [
      {
        'method': 'instapay',
        'account': 'salahly@instapay',
        'holder_name': 'شركة صلحلي',
      },
      {
        'method': 'wallet',
        'account': '01000000000',
        'holder_name': 'شركة صلحلي',
      },
    ];

    final result = await server.repository().fetchPaymentAccounts();

    expect((result as Ok).value, paymentAccounts);
    expect(server.last.url.path, '/rest/v1/payment_accounts');
  });

  test('fetchPaymentAccounts says an unknown method is unexpected', () async {
    server.body = [
      {'method': 'card', 'account': 'x', 'holder_name': 'y'},
    ];

    expect(
      await server.repository().fetchPaymentAccounts(),
      isA<Err<Object?>>().having(
        (err) => err.failure,
        'failure',
        isA<UnexpectedFailure>(),
      ),
    );
  });

  group('fetchTopups', () {
    test('reads the latest transfers of the role, newest first', () async {
      server.body = [
        {
          'id': 'topup-1',
          'uses': 5,
          'amount_piastres': 8000,
          'method': 'wallet',
          'status': 'rejected',
          'reject_reason': 'الصورة مش واضحة',
          'created_at': '2026-10-04T11:30:00+00:00',
        },
        {
          'id': 'topup-2',
          'uses': 1,
          'amount_piastres': 2000,
          'method': 'instapay',
          'status': 'pending',
          'reject_reason': null,
          'created_at': '2026-10-03T08:00:00+00:00',
        },
      ];

      final result = await server.repository().fetchTopups(UserRole.consumer);

      final topups = (result as Ok<List<Topup>>).value;
      expect(topups.map((topup) => topup.status), [
        TopupStatus.rejected,
        TopupStatus.pending,
      ]);
      expect(topups.first.method, TopupMethod.wallet);
      expect(topups.first.rejectReason, 'الصورة مش واضحة');
      expect(topups.first.createdAt.toUtc(), DateTime.utc(2026, 10, 4, 11, 30));
      expect(topups.last.rejectReason, isNull);
      expect(server.last.url.path, '/rest/v1/credit_topups');
      expect(server.last.url.queryParameters['role'], 'eq.consumer');
      expect(
        server.last.url.queryParameters['order'],
        'created_at.desc.nullslast',
      );
      expect(server.last.url.queryParameters['limit'], '50');
      expect(
        server.last.url.queryParameters['select'],
        isNot(contains('sender_account')),
      );
      expect(
        server.last.url.queryParameters['select'],
        isNot(contains('screenshot_path')),
      );
    });
  });

  group('fetchLedger', () {
    test('reads the latest movements of the role, newest first', () async {
      server.body = [
        {
          'id': 7,
          'delta': 5,
          'reason': 'topup',
          'created_at': '2026-10-04T12:00:00+00:00',
        },
        {
          'id': 6,
          'delta': -1,
          'reason': 'request_sent',
          'created_at': '2026-10-03T09:00:00+00:00',
        },
        {
          'id': 5,
          'delta': 1,
          'reason': 'request_refunded',
          'created_at': '2026-10-02T09:00:00+00:00',
        },
        {
          'id': 4,
          'delta': 2,
          'reason': 'admin_adjustment',
          'created_at': '2026-10-01T09:00:00+00:00',
        },
        {
          'id': 3,
          'delta': 3,
          'reason': 'free_grant',
          'created_at': '2026-09-30T09:00:00+00:00',
        },
        {
          'id': 2,
          'delta': 4,
          'reason': 'opening_balance',
          'created_at': '2026-09-29T09:00:00+00:00',
        },
      ];

      final result = await server.repository().fetchLedger(
        UserRole.technician,
      );

      final entries = (result as Ok<List<LedgerEntry>>).value;
      expect(entries.map((entry) => entry.reason), [
        LedgerReason.topup,
        LedgerReason.requestSent,
        LedgerReason.requestRefunded,
        LedgerReason.adminAdjustment,
        LedgerReason.freeGrant,
        LedgerReason.openingBalance,
      ]);
      expect(entries.map((entry) => entry.delta), [5, -1, 1, 2, 3, 4]);
      expect(server.last.url.path, '/rest/v1/credit_ledger');
      expect(server.last.url.queryParameters['role'], 'eq.technician');
      expect(server.last.url.queryParameters['limit'], '50');
    });
  });

  group('submitTopup', () {
    test(
      'sends only the pack, price, method, sender and screenshot',
      () async {
        server.body = 'topup-9';

        final result = await server.repository().submitTopup(
          packId: 'pack-5',
          method: TopupMethod.wallet,
          senderAccount: '01114567720',
          screenshotPath: 'consumer-1/proof.jpg',
          expectedPricePiastres: 8000,
        );

        expect((result as Ok<String>).value, 'topup-9');
        expect(server.last.url.path, '/rest/v1/rpc/submit_topup');
        expect(server.lastParams, {
          'p_pack_id': 'pack-5',
          'p_method': 'wallet',
          'p_sender_account': '01114567720',
          'p_screenshot_path': 'consumer-1/proof.jpg',
          'p_expected_price_piastres': 8000,
        });
      },
    );

    for (final (message, failure) in <(String, Failure)>[
      ('pack_not_found', const PackNotFoundFailure()),
      ('method_unavailable', const MethodUnavailableFailure()),
      ('invalid_sender', const InvalidSenderFailure()),
      ('invalid_screenshot', const InvalidScreenshotFailure()),
      ('price_changed', const PriceChangedFailure()),
      ('too_many_pending', const TooManyPendingFailure()),
    ]) {
      test('maps $message', () async {
        server.fails(message);

        expect(
          await server.repository().submitTopup(
            packId: 'pack-5',
            method: TopupMethod.instapay,
            senderAccount: 'a@instapay',
            screenshotPath: 'consumer-1/proof.jpg',
            expectedPricePiastres: 8000,
          ),
          _failure(failure),
        );
      });
    }

    test('keeps the sender out of an unexpected failure', () async {
      server.fails('something_else');

      final result = await server.repository().submitTopup(
        packId: 'pack-5',
        method: TopupMethod.wallet,
        senderAccount: '01114567720',
        screenshotPath: 'consumer-1/proof.jpg',
        expectedPricePiastres: 8000,
      );

      final failure = (result as Err<String>).failure;
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.toString(), isNot(contains('01114567720')));
    });

    test('reports a network failure offline', () async {
      server.offline = true;

      expect(
        await server.repository().submitTopup(
          packId: 'pack-5',
          method: TopupMethod.wallet,
          senderAccount: '01114567720',
          screenshotPath: 'consumer-1/proof.jpg',
          expectedPricePiastres: 8000,
        ),
        _failure(const NetworkFailure()),
      );
    });
  });

  test('uploadScreenshot refuses a file that is not an image', () async {
    expect(
      await server.repository().uploadScreenshot('/tmp/proof.pdf'),
      _failure(const UnsupportedPhotoFailure()),
    );
    expect(server.requests, isEmpty);
  });
}
