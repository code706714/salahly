import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/admin/data/repositories/supabase_requests_repository.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseRequestsRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseRequestsRepository(server.client);
  });

  group('fetchRequests', () {
    test('reads the requests and sends the filter', () async {
      server.body = {
        'total': 1,
        'items': [
          {
            'id': 'req-1',
            'code': 'R-1048',
            'created_at': '2026-10-07T08:00:00Z',
            'issue': 'not_cooling',
            'area_id': 'shubra',
            'area_name': 'شبرا',
            'consumer_name': 'منى',
            'technician_name': null,
            'offer_count': 0,
            'status': 'no_offers',
            'stars': null,
            'has_open_complaint': false,
            'has_complaint': true,
          },
        ],
      };

      final page = valueOf(
        await repository.fetchRequests(
          const RequestFilter(
            search: '  R-1048 ',
            areaId: 'shubra',
            status: AdminRequestStatus.awaitingChoice,
            days: 30,
          ),
          limit: 25,
          offset: 25,
        ),
      );

      expect(server.lastFunction, 'admin_list_requests');
      expect(server.lastParams, {
        'p_search': 'R-1048',
        'p_area_id': 'shubra',
        'p_status': 'awaiting_choice',
        'p_days': 30,
        'p_limit': 25,
        'p_offset': 25,
      });
      expect(page.items.single.issue, RequestIssue.notCooling);
      expect(page.items.single.status, AdminRequestStatus.noOffers);
      expect(page.items.single.hasComplaint, isTrue);
    });

    test('sends an empty box as no search and no filters as null', () async {
      server.body = {'total': 0, 'items': <Object>[]};

      await repository.fetchRequests(
        const RequestFilter(search: '   ', days: null),
        limit: 25,
        offset: 0,
      );

      expect(server.lastParams, {
        'p_search': null,
        'p_area_id': null,
        'p_status': null,
        'p_days': null,
        'p_limit': 25,
        'p_offset': 0,
      });
    });

    test('says when the server refused the search', () async {
      server.fails('invalid_search');

      expect(
        await repository.fetchRequests(
          const RequestFilter(search: 'x'),
          limit: 25,
          offset: 0,
        ),
        failsWith(const InvalidInputFailure()),
      );
    });
  });

  group('fetchComplaints', () {
    Map<String, Object?> complaint({Object? resolvedAt}) => {
      'id': 'complaint-1',
      'request_id': 'req-1',
      'request_code': 'R-1042',
      'reason': 'no_show_or_late',
      'details': '<b>ماردش</b>',
      'photo_path': null,
      'created_at': '2026-10-07T06:00:00Z',
      'resolved_at': resolvedAt,
      'resolution_note': null,
      'issue': 'noisy',
      'area_id': 'nasr_city',
      'consumer': {'id': 'c1', 'name': 'خالد', 'phone': '+201001234567'},
      'technician': {
        'id': 't1',
        'name': 'سامح',
        'phone': '+201112223334',
        'suspended': true,
      },
    };

    test('reads the complaints with both sides', () async {
      server.body = {
        'total': 1,
        'items': [complaint()],
      };

      final page = valueOf(
        await repository.fetchComplaints(
          ComplaintFilter.open,
          limit: 25,
          offset: 0,
        ),
      );

      expect(server.lastFunction, 'admin_list_complaints');
      expect(server.lastParams, {
        'p_status': 'open',
        'p_limit': 25,
        'p_offset': 0,
      });
      final first = page.items.single;
      expect(first.reason, ComplaintReason.noShowOrLate);
      expect(first.details, '<b>ماردش</b>');
      expect(first.consumer.suspended, isFalse);
      expect(first.technician.suspended, isTrue);
      expect(first.resolvedAt, isNull);
    });

    for (final filter in ComplaintFilter.values) {
      test('asks for ${filter.name} complaints', () async {
        server.body = {'total': 0, 'items': <Object>[]};

        await repository.fetchComplaints(filter, limit: 25, offset: 0);

        expect(server.lastParams['p_status'], filter.name);
      });
    }
  });

  test('closes a complaint with the note', () async {
    server.body = <String, Object?>{};

    await repository.resolveComplaint('complaint-1', 'كلمنا الفني');

    expect(server.lastFunction, 'admin_resolve_complaint');
    expect(server.lastParams, {
      'p_complaint_id': 'complaint-1',
      'p_note': 'كلمنا الفني',
    });
  });

  test('says when the complaint is gone', () async {
    server.fails('complaint_not_found');

    expect(
      await repository.resolveComplaint('gone', 'x'),
      failsWith(const AdminNotFoundFailure()),
    );
  });
}
