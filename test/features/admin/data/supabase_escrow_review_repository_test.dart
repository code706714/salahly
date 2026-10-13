import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/admin/data/repositories/supabase_escrow_review_repository.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
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
        'counts': {'pending': 1, 'released': 1},
        'items': [
          {
            'id': 'escrow-1',
            'request_code': 'R-1048',
            'status': 'released',
            'amount_piastres': 35000,
            'method': 'instapay',
            'sender_account': 'norhan@instapay',
            'screenshot_path': 'consumer/proof.jpg',
            'consumer_name': 'نورهان',
            'consumer_phone': '01114567720',
            'technician_name': 'محمود',
            'technician_phone': '01005550000',
            'payout_method': 'wallet',
            'payout_account': '01005551234',
            'payout_holder': 'محمود سعيد',
            'payout_reference': null,
            'refund_reference': null,
            'reject_reason': null,
            'dispute_reason': null,
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
            'payout_method': null,
            'payout_account': null,
            'payout_holder': null,
            'created_at': '2026-10-13T11:00:00Z',
          },
        ],
      };

      final page = valueOf(
        await repository.fetchEscrows(
          status: EscrowStatus.released,
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_escrows');
      expect(server.lastParams, {
        'p_status': 'released',
        'p_limit': 25,
        'p_offset': 0,
      });
      expect(page.total, 2);
      final paid = page.items.first;
      expect(paid.status, EscrowStatus.released);
      expect(paid.payoutMethod, TopupMethod.wallet);
      expect(paid.payoutAccount, '01005551234');
      expect(paid.resolutionNote, 'الفني كان على حق');
      expect(page.items.last.consumerName, isNull);
      expect(page.items.last.payoutMethod, isNull);
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

    test('records that the technician was paid', () async {
      await repository.markPaid('escrow-1', 'IP-123');

      expect(server.lastFunction, 'admin_mark_escrow_paid');
      expect(server.lastParams, {
        'p_escrow_id': 'escrow-1',
        'p_reference': 'IP-123',
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

  group('refusals', () {
    for (final (message, failure) in <(String, Failure)>[
      ('not_pending', const NotPendingFailure()),
      ('not_released', const NotPendingFailure()),
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
