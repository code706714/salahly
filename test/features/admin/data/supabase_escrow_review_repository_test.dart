import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/data/repositories/supabase_escrow_review_repository.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseEscrowReviewRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseEscrowReviewRepository(server.client);
  });

  group('fetchEscrows', () {
    test('reads what the team needs to check or pay', () async {
      server.body = {
        'total': 2,
        'counts': {'pending': 1, 'paid_out': 1},
        'items': [
          {
            'id': 'escrow-1',
            'request_code': 'R-1048',
            'status': 'disputed',
            'amount_piastres': 35000,
            'method': 'instapay',
            'sender_account': 'norhan@instapay',
            'screenshot_path': 'consumer/proof.jpg',
            'consumer_name': 'نورهان',
            'consumer_phone': '01114567720',
            'technician_name': 'محمود',
            'technician_phone': '01005550000',
            'refund_reference': null,
            'reject_reason': null,
            'dispute_reason': 'الفني ماجاش',
            'disputed_by': 'technician',
            'resolution_note': 'الفني كان على حق',
            'created_at': '2026-10-13T10:00:00Z',
          },
          {
            'id': 'escrow-2',
            'request_code': 'R-1049',
            'status': 'pending',
            'amount_piastres': 12000,
            'method': 'wallet',
            'sender_account': '01114567720',
            'screenshot_path': 'gone/proof.jpg',
            'consumer_name': null,
            'consumer_phone': null,
            'technician_name': null,
            'technician_phone': null,
            'created_at': '2026-10-13T11:00:00Z',
          },
        ],
      };

      final page = valueOf(
        await repository.fetchEscrows(
          status: EscrowStatus.disputed,
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_escrows');
      expect(server.lastParams, {
        'p_status': 'disputed',
        'p_limit': 25,
        'p_offset': 0,
      });
      expect(page.total, 2);
      final paid = page.items.first;
      expect(paid.status, EscrowStatus.disputed);
      expect(paid.disputedBy, EscrowDisputer.technician);
      expect(paid.resolutionNote, 'الفني كان على حق');
      expect(page.items.last.consumerName, isNull);
      expect(page.items.last.disputedBy, isNull);
    });

    test('sends no status as null, not left out', () async {
      server.body = {'total': 0, 'items': <Object>[]};

      await repository.fetchEscrows(status: null, limit: 25, offset: 25);

      expect(server.lastParams, {
        'p_status': null,
        'p_limit': 25,
        'p_offset': 25,
      });
    });

    test('says so when the server could not be reached', () async {
      server.offline = true;

      expect(
        await repository.fetchEscrows(status: null, limit: 25, offset: 0),
        failsWith(const NetworkFailure()),
      );
    });
  });

  group('the steps', () {
    setUp(() => server.body = <String, Object?>{});

    test('approves a transfer', () async {
      await repository.approve('escrow-1');

      expect(server.lastFunction, 'admin_approve_escrow');
      expect(server.lastParams, {'p_escrow_id': 'escrow-1'});
    });

    test('rejects a transfer with the reason the consumer reads', () async {
      await repository.reject('escrow-1', 'المبلغ ناقص');

      expect(server.lastFunction, 'admin_reject_escrow');
      expect(server.lastParams, {
        'p_escrow_id': 'escrow-1',
        'p_reason': 'المبلغ ناقص',
      });
    });

    test('settles a dispute for either side', () async {
      await repository.resolve(
        'escrow-1',
        payTechnician: false,
        note: 'الفني ماجاش',
      );

      expect(server.lastFunction, 'admin_resolve_escrow');
      expect(server.lastParams, {
        'p_escrow_id': 'escrow-1',
        'p_pay_technician': false,
        'p_note': 'الفني ماجاش',
      });
    });

    test('records that the consumer got her money back', () async {
      await repository.markRefunded('escrow-1', 'IP-999');

      expect(server.lastFunction, 'admin_mark_escrow_refunded');
      expect(server.lastParams, {
        'p_escrow_id': 'escrow-1',
        'p_reference': 'IP-999',
      });
    });
  });

  group('refundOnline', () {
    test('asks the refund function for the escrow, nothing else', () async {
      server.body = {'status': 'refunded'};

      final result = await repository.refundOnline('escrow-1');

      expect(result, isA<Ok<void>>());
      expect(server.last.url.path, '/functions/v1/payment-refund');
      expect(server.lastParams, {'escrow_id': 'escrow-1'});
    });

    for (final (name, failure) in <(String, Failure)>[
      ('refund_by_dashboard', const RefundByDashboardFailure()),
      ('admin_required', const AdminRequiredFailure()),
      ('recent_login_required', const RecentLoginRequiredFailure()),
      ('not_refund_due', const NotPendingFailure()),
      ('escrow_not_found', const AdminNotFoundFailure()),
    ]) {
      test('$name is a named failure', () async {
        server
          ..status = 400
          ..body = {'error': name};

        expect(await repository.refundOnline('escrow-1'), failsWith(failure));
      });
    }

    test('an unknown refusal is unexpected', () async {
      server
        ..status = 502
        ..body = {'error': 'provider_error'};

      expect(
        await repository.refundOnline('escrow-1'),
        isA<Err<Object?>>().having(
          (err) => err.failure,
          'failure',
          isA<UnexpectedFailure>(),
        ),
      );
    });

    test('says the network is down offline', () async {
      server.offline = true;

      expect(
        await repository.refundOnline('escrow-1'),
        failsWith(const NetworkFailure()),
      );
    });
  });

  group('refusals', () {
    for (final (message, failure) in <(String, Failure)>[
      ('not_pending', const NotPendingFailure()),
      ('not_disputed', const NotPendingFailure()),
      ('not_refund_due', const NotPendingFailure()),
      ('escrow_not_found', const AdminNotFoundFailure()),
      ('invalid_reason', const InvalidInputFailure()),
    ]) {
      test('$message is a named failure', () async {
        server.fails(message);

        expect(await repository.approve('escrow-1'), failsWith(failure));
      });
    }
  });
}
