import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/data/repositories/supabase_audit_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_users_repository.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;

  setUp(() => server = AdminServer());

  group('SupabaseUsersRepository', () {
    late SupabaseUsersRepository repository;

    setUp(() => repository = SupabaseUsersRepository(server.client));

    Map<String, Object?> account({Object? extra}) => {
      'id': 'u1',
      'name': 'سامي',
      'phone': '+201112345678',
      'area_id': 'nasr_city',
      'area_name': 'مدينة نصر',
      'balance': 4,
      'pending_topup': true,
      'created_at': '2026-09-01T00:00:00Z',
      'last_sign_in_at': null,
      'suspension_reason': null,
    };

    test('reads technicians', () async {
      server.body = {
        'total': 1,
        'items': [
          {
            ...account(),
            'status': 'verified',
            'verification_status': 'approved',
            'rating': 4.5,
            'review_count': 12,
            'platform_jobs': 8,
          },
        ],
      };

      final page = valueOf(
        await repository.fetchUsers(
          const UserFilter(
            search: ' سامي ',
            areaId: 'nasr_city',
            status: AccountStatus.verified,
          ),
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_users');
      expect(server.lastParams, {
        'p_role': 'technician',
        'p_search': 'سامي',
        'p_area_id': 'nasr_city',
        'p_status': 'verified',
        'p_limit': 25,
        'p_offset': 0,
      });
      final technician = page.items.single as AdminTechnician;
      expect(technician.verificationStatus, VerificationStatus.approved);
      expect(technician.rating, 4.5);
      expect(technician.lastSignInAt, isNull);
    });

    test('reads consumers and sends no filters as null', () async {
      server.body = {
        'total': 1,
        'items': [
          {
            ...account(),
            'status': 'suspended',
            'suspension_reason': 'شكاوي',
            'requests_count': 4,
            'last_request_at': '2026-10-01T00:00:00Z',
            'complaints_count': 1,
          },
        ],
      };

      final page = valueOf(
        await repository.fetchUsers(
          const UserFilter(role: UserRole.consumer),
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastParams, {
        'p_role': 'consumer',
        'p_search': null,
        'p_area_id': null,
        'p_status': null,
        'p_limit': 25,
        'p_offset': 0,
      });
      final consumer = page.items.single as AdminConsumer;
      expect(consumer.status, AccountStatus.suspended);
      expect(consumer.suspensionReason, 'شكاوي');
      expect(consumer.lastRequestAt, isNotNull);
    });

    test('suspends an account with the reason', () async {
      server.body = <String, Object?>{};

      await repository.suspend('u1', 'شكاوي متكررة');

      expect(server.lastFunction, 'admin_suspend_user');
      expect(server.lastParams, {
        'p_user_id': 'u1',
        'p_reason': 'شكاوي متكررة',
      });
    });

    test('refuses to suspend an admin', () async {
      server.fails('cannot_suspend_admin');

      expect(
        await repository.suspend('admin-2', 'x'),
        failsWith(const CannotSuspendAdminFailure()),
      );
    });

    test('restores an account', () async {
      server.body = <String, Object?>{};

      await repository.restore('u1');

      expect(server.lastFunction, 'admin_restore_user');
      expect(server.lastParams, {'p_user_id': 'u1'});
    });
  });

  group('SupabaseAuditRepository', () {
    late SupabaseAuditRepository repository;

    setUp(() => repository = SupabaseAuditRepository(server.client));

    test('reads the log, with and without a name or details', () async {
      server.body = {
        'total': 2,
        'items': [
          {
            'id': 2,
            'admin_id': 'admin-1',
            'admin_name': 'أحمد',
            'action': 'approve_topup',
            'target_type': 'topup',
            'target_id': 'topup-1',
            'details': {'reason': 'تمام'},
            'created_at': '2026-10-07T09:00:00Z',
          },
          {
            'id': 1,
            'admin_id': 'admin-1',
            'admin_name': null,
            'action': 'suspend_user',
            'target_type': 'user',
            'target_id': null,
            'details': null,
            'created_at': '2026-10-06T09:00:00Z',
          },
        ],
      };

      final page = valueOf(
        await repository.fetchLog(
          const AuditFilter(action: 'approve_topup', targetId: ' topup-1 '),
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_audit_log');
      expect(server.lastParams, {
        'p_action': 'approve_topup',
        'p_target_id': 'topup-1',
        'p_limit': 25,
        'p_offset': 0,
      });
      expect(page.total, 2);
      expect(page.items.first.details, {'reason': 'تمام'});
      expect(page.items.last.adminName, isNull);
      expect(page.items.last.targetId, isNull);
      expect(page.items.last.details, isEmpty);
    });

    test('sends an empty filter as null', () async {
      server.body = {'total': 0, 'items': <Object>[]};

      await repository.fetchLog(const AuditFilter(), limit: 25, offset: 0);

      expect(server.lastParams['p_action'], isNull);
      expect(server.lastParams['p_target_id'], isNull);
    });

    test('says when the server refused the filter', () async {
      server.fails('invalid_filter');

      expect(
        await repository.fetchLog(const AuditFilter(), limit: 25, offset: 0),
        failsWith(const InvalidInputFailure()),
      );
    });
  });
}
