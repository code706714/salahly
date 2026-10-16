import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/admin/data/repositories/supabase_activity_repository.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseActivityRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseActivityRepository(server.client);
  });

  group('fetchMoney', () {
    test('reads what came in, what was earned and what went out', () async {
      server.body = {
        'earned_piastres': 15000,
        'paid_in': {
          'count': 2,
          'total_piastres': 25000,
          'escrow_piastres': 10000,
        },
        'released_to_wallets_piastres': 8000,
        'withdrawals': {
          'requested_count': 1,
          'requested_piastres': 5000,
          'paid_count': 1,
          'paid_piastres': 4000,
          'waiting_count': 2,
          'waiting_piastres': 9000,
        },
        'transactions': [
          {
            'kind': 'pack_payment',
            'amount_piastres': 15000,
            'person_name': 'كريم',
            'method': 'card',
            'at': '2026-10-15T09:00:00Z',
          },
          {
            'kind': 'withdrawal_requested',
            'amount_piastres': 5000,
            'person_name': null,
            'method': null,
            'at': '2026-10-15T08:00:00Z',
          },
        ],
      };

      final money = valueOf(await repository.fetchMoney(OverviewPeriod.today));

      expect(server.lastFunction, 'admin_money_summary');
      expect(server.lastParams, {'p_period': 'today'});
      expect(money.earnedPiastres, 15000);
      expect(money.escrowPaidInPiastres, 10000);
      expect(money.withdrawals.waitingPiastres, 9000);
      expect(money.transactions.first.kind, MoneyTransactionKind.packPayment);
      expect(money.transactions.first.personName, 'كريم');
      expect(
        money.transactions.last.kind,
        MoneyTransactionKind.withdrawalRequested,
      );
      expect(money.transactions.last.personName, isNull);
    });

    test('says no one is allowed when the account is not an admin', () async {
      server.fails('admin_required');

      expect(
        await repository.fetchMoney(OverviewPeriod.week),
        failsWith(const AdminRequiredFailure()),
      );
    });

    test('says so when the server could not be reached', () async {
      server.offline = true;

      expect(
        await repository.fetchMoney(OverviewPeriod.month),
        failsWith(const NetworkFailure()),
      );
    });
  });

  group('fetchTechnicians', () {
    test('reads each technician with their customers and jobs', () async {
      server.body = {
        'technicians_active': 1,
        'jobs_count': 3,
        'finished_count': 2,
        'billed_piastres': 90000,
        'technicians': [
          {
            'id': 't1',
            'name': 'كريم',
            'phone': '+201001234567',
            'jobs_count': 3,
            'finished_count': 2,
            'customers_count': 2,
            'billed_piastres': 90000,
            'paid_piastres': 50000,
            'jobs': [
              {
                'id': 'j1',
                'customer_name': 'منى',
                'status': 'paid',
                'source': 'platform',
                'description': 'تغيير خلاط',
                'total_piastres': 60000,
                'paid_piastres': 60000,
                'at': '2026-10-15T08:00:00Z',
              },
              {
                'id': 'j2',
                'customer_name': null,
                'status': 'started',
                'source': 'own',
                'description': null,
                'total_piastres': 0,
                'paid_piastres': 0,
                'at': '2026-10-15T07:00:00Z',
              },
            ],
          },
        ],
      };

      final report = valueOf(
        await repository.fetchTechnicians(OverviewPeriod.week),
      );

      expect(server.lastFunction, 'admin_technician_activity');
      expect(server.lastParams, {'p_period': 'week', 'p_limit': 100});
      expect(report.techniciansActive, 1);
      final technician = report.technicians.single;
      expect(technician.name, 'كريم');
      expect(technician.customersCount, 2);
      expect(technician.jobs.first.status, JobStatus.paid);
      expect(technician.jobs.first.isFromApp, isTrue);
      expect(technician.jobs.last.isFromApp, isFalse);
      expect(technician.jobs.last.customerName, isNull);
    });
  });
}
