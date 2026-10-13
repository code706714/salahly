import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/data/repositories/supabase_escrow_repository.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Object? body;
  late int status;
  late bool offline;
  late List<http.Request> requests;

  setUp(() {
    body = null;
    status = 200;
    offline = false;
    requests = [];
  });

  SupabaseEscrowRepository repository() => SupabaseEscrowRepository(
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

  void refuse(String message, {String code = 'P0001'}) {
    status = 400;
    body = {'code': code, 'message': message, 'details': null};
  }

  Future<Result<void>> Function() call(String name) => switch (name) {
    'secure' => () => repository().secure(
      requestId: 'request-1',
      method: TopupMethod.wallet,
      senderAccount: '01114567720',
      screenshotPath: 'consumer-1/proof.jpg',
    ),
    'confirm' => () => repository().confirmWork('request-1'),
    'dispute' => () => repository().dispute('request-1', 'ماجاش'),
    _ => () => repository().savePayoutAccount(
      const PayoutAccount(
        method: TopupMethod.wallet,
        account: '01114567720',
        holderName: 'محمود سعيد',
      ),
    ),
  };

  group('reading the consumer view', () {
    test('reads the amount, what she can do and the payment', () async {
      body = {
        'amount_piastres': 35000,
        'can_secure': false,
        'can_confirm': true,
        'can_dispute': true,
        'accounts': [
          {
            'method': 'instapay',
            'account': 'salahly@instapay',
            'holder_name': 'شركة صلحلي',
          },
        ],
        'escrow': {
          'id': 'escrow-1',
          'status': 'held',
          'method': 'instapay',
          'reject_reason': null,
          'created_at': '2026-10-13T10:00:00+00:00',
          'held_at': '2026-10-13T11:00:00+00:00',
          'auto_release_at': '2026-10-16T10:00:00+00:00',
        },
      };

      final result = await repository().fetchInfo('request-1');

      expect(requests.single.url.path, '/rest/v1/rpc/escrow_info');
      expect(jsonDecode(requests.single.body), {'p_request_id': 'request-1'});
      final info = (result as Ok<EscrowInfo?>).value!;
      expect(info.amountPiastres, 35000);
      expect(info.canSecure, isFalse);
      expect(info.canConfirm, isTrue);
      expect(info.canDispute, isTrue);
      expect(info.accounts.single.account, 'salahly@instapay');
      expect(info.escrow!.status, EscrowStatus.held);
      expect(info.escrow!.method, TopupMethod.instapay);
      expect(
        info.escrow!.autoReleaseAt,
        DateTime.utc(2026, 10, 16, 10).toLocal(),
      );
    });

    test('reads a request with no payment yet', () async {
      body = {
        'amount_piastres': 35000,
        'can_secure': true,
        'can_confirm': false,
        'can_dispute': false,
        'accounts': <Object?>[],
        'escrow': null,
      };

      final info =
          ((await repository().fetchInfo('r')) as Ok<EscrowInfo?>).value!;

      expect(info.canSecure, isTrue);
      expect(info.escrow, isNull);
      expect(info.isRelevant, isTrue);
    });

    test('reads a rejected payment with its reason', () async {
      body = {
        'amount_piastres': 35000,
        'can_secure': true,
        'can_confirm': false,
        'can_dispute': false,
        'accounts': <Object?>[],
        'escrow': {
          'id': 'escrow-1',
          'status': 'rejected',
          'method': 'wallet',
          'reject_reason': 'المبلغ ناقص',
          'created_at': '2026-10-13T10:00:00+00:00',
          'held_at': null,
          'auto_release_at': null,
        },
      };

      final info =
          ((await repository().fetchInfo('r')) as Ok<EscrowInfo?>).value!;

      expect(info.escrow!.status, EscrowStatus.rejected);
      expect(info.escrow!.rejectReason, 'المبلغ ناقص');
    });

    test("is null for a request that isn't hers", () async {
      body = null;

      expect(
        ((await repository().fetchInfo('r')) as Ok<EscrowInfo?>).value,
        isNull,
      );
    });

    test('says when the network is down', () async {
      offline = true;

      expect(
        await repository().fetchInfo('r'),
        isA<Err<EscrowInfo?>>().having(
          (err) => err.failure,
          'failure',
          const NetworkFailure(),
        ),
      );
    });
  });

  group('the technician', () {
    test('reads the payment of his request', () async {
      body = {'status': 'paid_out', 'amount_piastres': 35000};

      final result = await repository().fetchTechnicianEscrow('request-1');

      expect(requests.single.url.path, '/rest/v1/rpc/technician_escrow');
      final escrow = (result as Ok<TechnicianEscrow?>).value!;
      expect(escrow.status, EscrowStatus.paidOut);
      expect(escrow.amountPiastres, 35000);
    });

    test('reads that there is no payment', () async {
      body = null;

      expect(
        ((await repository().fetchTechnicianEscrow('r'))
                as Ok<TechnicianEscrow?>)
            .value,
        isNull,
      );
    });

    test('reads the payout account, or none', () async {
      body = {
        'method': 'wallet',
        'account': '01114567720',
        'holder_name': 'محمود سعيد',
      };

      final account =
          ((await repository().fetchPayoutAccount()) as Ok<PayoutAccount?>)
              .value!;

      expect(requests.single.url.path, '/rest/v1/rpc/my_payout_account');
      expect(account.method, TopupMethod.wallet);
      expect(account.account, '01114567720');
      expect(account.holderName, 'محمود سعيد');

      body = null;
      expect(
        ((await repository().fetchPayoutAccount()) as Ok<PayoutAccount?>).value,
        isNull,
      );
    });
  });

  group('writing', () {
    test('secures the payment with the transfer', () async {
      body = null;
      status = 204;

      final result = await call('secure')();

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, '/rest/v1/rpc/secure_payment');
      expect(jsonDecode(requests.single.body), {
        'p_request_id': 'request-1',
        'p_method': 'wallet',
        'p_sender_account': '01114567720',
        'p_screenshot_path': 'consumer-1/proof.jpg',
      });
    });

    test('confirms the work, disputes it and saves the account', () async {
      status = 204;

      await call('confirm')();
      await call('dispute')();
      await call('save')();

      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/confirm_work_done',
        '/rest/v1/rpc/dispute_payment',
        '/rest/v1/rpc/save_payout_account',
      ]);
      expect(jsonDecode(requests[1].body), {
        'p_request_id': 'request-1',
        'p_reason': 'ماجاش',
      });
      expect(jsonDecode(requests[2].body), {
        'p_method': 'wallet',
        'p_account': '01114567720',
        'p_holder_name': 'محمود سعيد',
      });
    });

    for (final (action, message, code, failure)
        in <(String, String, String, Failure)>[
          (
            'secure',
            'escrow_unavailable',
            'P0001',
            const EscrowUnavailableFailure(),
          ),
          ('secure', 'not_found', 'P0002', const EscrowUnavailableFailure()),
          ('secure', 'already_secured', 'P0001', const AlreadySecuredFailure()),
          (
            'secure',
            'method_unavailable',
            '22023',
            const MethodUnavailableFailure(),
          ),
          ('secure', 'invalid_sender', '22023', const InvalidSenderFailure()),
          (
            'secure',
            'invalid_screenshot',
            '22023',
            const InvalidScreenshotFailure(),
          ),
          (
            'confirm',
            'escrow_unavailable',
            'P0001',
            const EscrowUnavailableFailure(),
          ),
          ('dispute', 'invalid_reason', '22023', const InvalidReasonFailure()),
          ('save', 'invalid_holder', '22023', const InvalidHolderFailure()),
          (
            'save',
            'invalid_account',
            '22023',
            const InvalidPayoutAccountFailure(),
          ),
          ('save', 'rate_limited', '54000', const RateLimitedFailure()),
        ]) {
      test('$action says why it was refused: $message', () async {
        refuse(message, code: code);

        expect(
          await call(action)(),
          isA<Err<void>>().having((err) => err.failure, 'failure', failure),
        );
      });
    }
  });
}
