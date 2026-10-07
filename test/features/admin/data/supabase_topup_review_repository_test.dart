import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/data/repositories/supabase_topup_review_repository.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseTopupReviewRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseTopupReviewRepository(server.client);
  });

  group('fetchTopups', () {
    test('reads the transfers, even of an account that was deleted', () async {
      server.body = {
        'total': 2,
        'items': [
          {
            'id': 'topup-1',
            'user_id': 'user-1',
            'name': 'سامي',
            'account_phone': '01012345678',
            'role': 'technician',
            'uses': 10,
            'amount_piastres': 25000,
            'method': 'wallet',
            'sender_account': '01012345678',
            'screenshot_path': 'user/proof.jpg',
            'status': 'pending',
            'reject_reason': null,
            'created_at': '2026-10-07T10:00:00Z',
            'reviewed_at': null,
          },
          {
            'id': 'topup-2',
            'user_id': null,
            'name': null,
            'account_phone': null,
            'role': 'consumer',
            'uses': 5,
            'amount_piastres': 8000,
            'method': 'instapay',
            'sender_account': 'a@instapay',
            'screenshot_path': 'gone/proof.jpg',
            'status': 'rejected',
            'reject_reason': 'المبلغ مش مظبوط',
            'created_at': '2026-10-06T10:00:00Z',
            'reviewed_at': '2026-10-06T11:00:00Z',
          },
        ],
      };

      final page = valueOf(
        await repository.fetchTopups(
          status: TopupStatus.pending,
          role: UserRole.technician,
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_topups');
      expect(server.lastParams, {
        'p_status': 'pending',
        'p_role': 'technician',
        'p_limit': 25,
        'p_offset': 0,
      });
      expect(page.total, 2);
      expect(page.items.first.method, TopupMethod.wallet);
      expect(page.items.last.userId, isNull);
      expect(page.items.last.rejectReason, 'المبلغ مش مظبوط');
    });

    test('sends no status and no side as null, not left out', () async {
      server.body = {'total': 0, 'items': <Object>[]};

      await repository.fetchTopups(
        status: null,
        role: null,
        limit: 25,
        offset: 25,
      );

      expect(server.lastParams, {
        'p_status': null,
        'p_role': null,
        'p_limit': 25,
        'p_offset': 25,
      });
    });

    test('says so when the server could not be reached', () async {
      server.offline = true;

      expect(
        await repository.fetchTopups(
          status: null,
          role: null,
          limit: 25,
          offset: 0,
        ),
        failsWith(const NetworkFailure()),
      );
    });
  });

  test('approves a transfer', () async {
    server.body = <String, Object?>{};

    await repository.approve('topup-1');

    expect(server.lastFunction, 'admin_approve_topup');
    expect(server.lastParams, {'p_topup_id': 'topup-1'});
  });

  test('rejects a transfer with its reason', () async {
    server.body = <String, Object?>{};

    await repository.reject('topup-1', 'المبلغ مش مظبوط');

    expect(server.lastFunction, 'admin_reject_topup');
    expect(server.lastParams, {
      'p_topup_id': 'topup-1',
      'p_reason': 'المبلغ مش مظبوط',
    });
  });

  test('says when a transfer was reviewed already', () async {
    server.fails('not_pending');

    expect(
      await repository.approve('topup-1'),
      failsWith(const NotPendingFailure()),
    );
  });
}
