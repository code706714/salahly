import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/admin/data/repositories/supabase_withdrawal_review_repository.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseWithdrawalReviewRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseWithdrawalReviewRepository(server.client);
  });

  group('fetchWithdrawals', () {
    test('reads what the team has to send', () async {
      server.body = {
        'total': 2,
        'items': [
          {
            'id': 'w-1',
            'status': 'requested',
            'amount_piastres': 20000,
            'method': 'wallet',
            'account': '01005551234',
            'holder_name': 'محمود سعيد',
            'technician_name': 'محمود',
            'technician_phone': '01005550000',
            'reference': null,
            'reject_reason': null,
            'created_at': '2026-10-15T10:00:00Z',
            'processed_at': null,
          },
          {
            'id': 'w-2',
            'status': 'paid',
            'amount_piastres': 5000,
            'method': 'instapay',
            'account': 'm@instapay',
            'holder_name': 'محمود سعيد',
            'technician_name': null,
            'technician_phone': null,
            'reference': 'IP-1',
            'reject_reason': null,
            'created_at': '2026-10-14T10:00:00Z',
            'processed_at': '2026-10-14T12:00:00Z',
          },
        ],
      };

      final page = valueOf(
        await repository.fetchWithdrawals(
          status: WithdrawalStatus.requested,
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_withdrawals');
      expect(server.lastParams, {
        'p_status': 'requested',
        'p_limit': 25,
        'p_offset': 0,
      });
      expect(page.total, 2);
      final first = page.items.first;
      expect(first.status, WithdrawalStatus.requested);
      expect(first.method, TopupMethod.wallet);
      expect(first.account, '01005551234');
      expect(first.processedAt, isNull);
      final paid = page.items.last;
      expect(paid.reference, 'IP-1');
      expect(paid.technicianName, isNull);
      expect(paid.processedAt, isNotNull);
    });

    test('sends no status as null, not left out', () async {
      server.body = {'total': 0, 'items': <Object>[]};

      await repository.fetchWithdrawals(status: null, limit: 25, offset: 25);

      expect(server.lastParams, {
        'p_status': null,
        'p_limit': 25,
        'p_offset': 25,
      });
    });

    test('says why it did not load', () async {
      server.fails('admin_required');

      expect(
        await repository.fetchWithdrawals(status: null, limit: 25, offset: 0),
        failsWith(const AdminRequiredFailure()),
      );
    });
  });

  group('steps', () {
    setUp(() => server.body = <String, Object?>{});

    test('records that the money was sent', () async {
      await repository.markPaid('w-1', 'IP-123');

      expect(server.lastFunction, 'admin_mark_withdrawal_paid');
      expect(server.lastParams, {
        'p_withdrawal_id': 'w-1',
        'p_reference': 'IP-123',
      });
    });

    test('rejects with the reason the technician reads', () async {
      await repository.reject('w-1', 'الرقم غلط');

      expect(server.lastFunction, 'admin_reject_withdrawal');
      expect(server.lastParams, {
        'p_withdrawal_id': 'w-1',
        'p_reason': 'الرقم غلط',
      });
    });
  });
}
