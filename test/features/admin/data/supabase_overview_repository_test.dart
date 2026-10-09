import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/data/repositories/supabase_overview_repository.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseOverviewRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseOverviewRepository(server.client);
  });

  group('fetchOverview', () {
    test('reads the numbers of the period', () async {
      server.body = {
        'period': 'week',
        'verified_technicians': 76,
        'verified_technician_target': 100,
        'requests': {'count': 142, 'previous_count': 124},
        'funnel': {
          'sent': 142,
          'with_offer': 133,
          'chosen': 104,
          'finished': 91,
        },
        'rating': {'average': 4.6, 'count': 91},
        'requests_without_offers': {
          'count': 9,
          'older_than_hours': 3,
          'top_areas': [
            {'area_id': 'shubra', 'name_ar': 'شبرا', 'count': 6},
          ],
        },
        'pending_verifications': {
          'count': 12,
          'oldest_at': '2026-10-05T10:00:00Z',
        },
        'open_complaints': {
          'count': 3,
          'by_reason': {'poor_work': 2, 'other': 1, 'unknown_reason': 5},
        },
        'pending_topups': {'count': 7, 'technicians': 4, 'consumers': 3},
        'low_rated_technicians': [
          {'id': 't1', 'name': 'كريم', 'rating': 3, 'review_count': 14},
        ],
      };

      final overview = valueOf(
        await repository.fetchOverview(OverviewPeriod.week),
      );

      expect(server.lastFunction, 'admin_overview');
      expect(server.lastParams, {'p_period': 'week'});
      expect(overview.period, OverviewPeriod.week);
      expect(overview.requests.previousCount, 124);
      expect(overview.funnel.finished, 91);
      expect(overview.rating.average, 4.6);
      expect(overview.unanswered.topAreas.single.name, 'شبرا');
      expect(overview.pendingVerifications.oldestAt, isNotNull);
      expect(overview.openComplaints.byReason, {
        ComplaintReason.poorWork: 2,
        ComplaintReason.other: 1,
      });
      expect(overview.pendingTopups.consumers, 3);
      expect(overview.lowRated.single.rating, 3.0);
    });

    test('says no one is allowed when the account is not an admin', () async {
      server.fails('admin_required');

      expect(
        await repository.fetchOverview(OverviewPeriod.today),
        failsWith(const AdminRequiredFailure()),
      );
    });

    test('says so when the server could not be reached', () async {
      server.offline = true;

      expect(
        await repository.fetchOverview(OverviewPeriod.month),
        failsWith(const NetworkFailure()),
      );
    });

    test('reports an answer it cannot read as unexpected', () async {
      server.body = {'period': 'decade'};

      expect(
        await repository.fetchOverview(OverviewPeriod.week),
        isA<Err<Object?>>().having(
          (err) => err.failure,
          'failure',
          isA<UnexpectedFailure>(),
        ),
      );
    });
  });

  group('fetchAreas', () {
    test('reads the coverage of each area with the page asked for', () async {
      server.body = {
        'ads_min_technicians': 10,
        'total': 1,
        'items': [
          {
            'id': 'shubra',
            'name_ar': 'شبرا',
            'city_ar': 'القاهرة',
            'is_open': true,
            'verified_technicians': 6,
            'requests': 12,
            'got_offer_percent': null,
            'ads_active': false,
          },
        ],
      };

      final report = valueOf(
        await repository.fetchAreas(OverviewPeriod.month, limit: 50, offset: 0),
      );

      expect(server.lastFunction, 'admin_list_areas');
      expect(server.lastParams, {
        'p_period': 'month',
        'p_limit': 50,
        'p_offset': 0,
      });
      expect(report.adsMinTechnicians, 10);
      expect(report.areas, const [
        AreaCoverage(
          id: 'shubra',
          name: 'شبرا',
          city: 'القاهرة',
          isOpen: true,
          verifiedTechnicians: 6,
          requests: 12,
          adsActive: false,
        ),
      ]);
    });
  });
}
