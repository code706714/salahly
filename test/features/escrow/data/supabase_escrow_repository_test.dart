import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/data/repositories/supabase_escrow_repository.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
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
    'confirm' => () => repository().confirmWork('request-1'),
    'dispute' => () => repository().dispute('request-1', 'ماجاش'),
    'technician_confirm' => () => repository().technicianConfirmWork('r1'),
    _ => () => repository().technicianDispute('request-1', 'العميل رفض'),
  };

  group('reading the consumer view', () {
    test('reads the amount, what she can do and the payment', () async {
      body = {
        'amount_piastres': 35000,
        'can_secure': false,
        'can_confirm': true,
        'can_dispute': true,
        'payment': {'status': 'succeeded'},
        'escrow': {
          'id': 'escrow-1',
          'status': 'held',
          'method': 'instapay',
          'reject_reason': null,
          'created_at': '2026-10-13T10:00:00+00:00',
          'held_at': '2026-10-13T11:00:00+00:00',
          'consumer_confirmed': true,
          'technician_confirmed': false,
          'release_at': '2026-10-16T10:00:00+00:00',
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
      expect(info.paymentStatus, PaymentStatus.succeeded);
      expect(info.paymentInProgress, isFalse);
      expect(info.escrow!.status, EscrowStatus.held);
      expect(info.escrow!.method, TopupMethod.instapay);
      expect(info.escrow!.consumerConfirmed, isTrue);
      expect(info.escrow!.technicianConfirmed, isFalse);
      expect(
        info.escrow!.releaseAt,
        DateTime.utc(2026, 10, 16, 10).toLocal(),
      );
    });

    test('reads a request with no payment yet', () async {
      body = {
        'amount_piastres': 35000,
        'can_secure': true,
        'can_confirm': false,
        'can_dispute': false,
        'payment': null,
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
        'payment': null,
        'escrow': {
          'id': 'escrow-1',
          'status': 'rejected',
          'method': 'wallet',
          'reject_reason': 'المبلغ ناقص',
          'created_at': '2026-10-13T10:00:00+00:00',
          'held_at': null,
          'consumer_confirmed': false,
          'technician_confirmed': false,
          'release_at': null,
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
      body = {
        'status': 'held',
        'amount_piastres': 35000,
        'can_confirm': true,
        'can_dispute': true,
        'consumer_confirmed': true,
        'technician_confirmed': false,
        'release_at': null,
      };

      final result = await repository().fetchTechnicianEscrow('request-1');

      expect(requests.single.url.path, '/rest/v1/rpc/technician_escrow');
      final escrow = (result as Ok<TechnicianEscrow?>).value!;
      expect(escrow.status, EscrowStatus.held);
      expect(escrow.amountPiastres, 35000);
      expect(escrow.canConfirm, isTrue);
      expect(escrow.canDispute, isTrue);
      expect(escrow.consumerConfirmed, isTrue);
      expect(escrow.technicianConfirmed, isFalse);
      expect(escrow.releaseAt, isNull);
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
  });

  group('writing', () {
    test('confirms the work and disputes it, from either side', () async {
      status = 204;

      await call('confirm')();
      await call('dispute')();
      await call('technician_confirm')();
      await call('technician_dispute')();

      expect(requests.map((r) => r.url.path), [
        '/rest/v1/rpc/confirm_work_done',
        '/rest/v1/rpc/dispute_payment',
        '/rest/v1/rpc/technician_confirm_work_done',
        '/rest/v1/rpc/technician_dispute_payment',
      ]);
      expect(jsonDecode(requests[1].body), {
        'p_request_id': 'request-1',
        'p_reason': 'ماجاش',
      });
      expect(jsonDecode(requests[3].body), {
        'p_request_id': 'request-1',
        'p_reason': 'العميل رفض',
      });
    });

    for (final (action, message, code, failure)
        in <(String, String, String, Failure)>[
          (
            'confirm',
            'escrow_unavailable',
            'P0001',
            const EscrowUnavailableFailure(),
          ),
          ('dispute', 'invalid_reason', '22023', const InvalidReasonFailure()),
          (
            'technician_confirm',
            'escrow_unavailable',
            'P0001',
            const EscrowUnavailableFailure(),
          ),
          (
            'technician_dispute',
            'invalid_reason',
            '22023',
            const InvalidReasonFailure(),
          ),
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
