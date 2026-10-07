import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/data/repositories/supabase_verification_repository.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseVerificationRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseVerificationRepository(server.client);
  });

  group('fetchQueue', () {
    test('reads the page of the status asked for', () async {
      server.body = {
        'total': 12,
        'items': [
          {
            'verification_id': 'ver-1',
            'technician_id': 'tech-1',
            'name': 'نورهان',
            'area_id': 'nasr_city',
            'area_name': 'مدينة نصر',
            'status': 'pending',
            'submitted_at': '2026-10-07T07:00:00Z',
            'reviewed_at': null,
            'rejection_reason': null,
            'suspended': false,
          },
        ],
      };

      final page = valueOf(
        await repository.fetchQueue(
          VerificationStatus.pending,
          limit: 25,
          offset: 50,
        ),
      );

      expect(server.lastFunction, 'admin_list_verifications');
      expect(server.lastParams, {
        'p_status': 'pending',
        'p_limit': 25,
        'p_offset': 50,
      });
      expect(page.total, 12);
      expect(page.items.single.verificationId, 'ver-1');
      expect(page.items.single.status, VerificationStatus.pending);
      expect(page.items.single.reviewedAt, isNull);
    });
  });

  group('fetchDetail', () {
    test('reads the file with the paths of the photos', () async {
      server.body = {
        'verification_id': 'ver-1',
        'technician_id': 'tech-1',
        'status': 'rejected',
        'submitted_at': '2026-10-07T07:00:00Z',
        'reviewed_at': '2026-10-07T08:00:00Z',
        'rejection_reason': 'الصورة مش واضحة',
        'id_front_path': 'tech/front.jpg',
        'id_back_path': 'tech/back.jpg',
        'selfie_path': 'tech/selfie.jpg',
        'name': 'نورهان',
        'phone': '+201112345678',
        'phone_confirmed': true,
        'shop_name': null,
        'years_experience': 6,
        'area_id': 'nasr_city',
        'area_name': 'مدينة نصر',
        'service_radius_km': 10,
        'work_days': [6, 7, 1],
        'suspended': false,
        'previous_attempts': 2,
        'areas': [
          {'id': 'nasr_city', 'name_ar': 'مدينة نصر'},
        ],
        'services': [
          {
            'service_id': 'ac_repair',
            'name_ar': 'صيانة تكييف',
            'starting_price_piastres': 25000,
          },
        ],
      };

      final detail = valueOf(await repository.fetchDetail('ver-1'));

      expect(server.lastFunction, 'admin_get_verification');
      expect(server.lastParams, {'p_verification_id': 'ver-1'});
      expect(detail.status, VerificationStatus.rejected);
      expect(detail.idFrontPath, 'tech/front.jpg');
      expect(detail.shopName, isNull);
      expect(detail.workDays, {6, 7, 1});
      expect(detail.previousAttempts, 2);
      expect(detail.services.single.startingPricePiastres, 25000);
    });

    test('says when the file is gone', () async {
      server.fails('verification_not_found');

      expect(
        await repository.fetchDetail('gone'),
        failsWith(const AdminNotFoundFailure()),
      );
    });
  });

  group('approve', () {
    test('approves the file', () async {
      server.body = <String, Object?>{};

      final result = await repository.approve('ver-1');

      expect(result, isA<Ok<void>>());
      expect(server.lastFunction, 'admin_approve_verification');
      expect(server.lastParams, {'p_verification_id': 'ver-1'});
    });

    test('says when it was already reviewed', () async {
      server.fails('not_pending');

      expect(
        await repository.approve('ver-1'),
        failsWith(const NotPendingFailure()),
      );
    });

    test('asks for a fresh sign-in', () async {
      server.fails('recent_login_required');

      expect(
        await repository.approve('ver-1'),
        failsWith(const RecentLoginRequiredFailure()),
      );
    });
  });

  group('reject', () {
    test('sends the reason the technician will read', () async {
      server.body = <String, Object?>{};

      await repository.reject('ver-1', 'الصورة مش واضحة');

      expect(server.lastFunction, 'admin_reject_verification');
      expect(server.lastParams, {
        'p_verification_id': 'ver-1',
        'p_reason': 'الصورة مش واضحة',
      });
    });

    test('says when the reason was refused', () async {
      server.fails('invalid_reason');

      expect(
        await repository.reject('ver-1', 'x'),
        failsWith(const InvalidInputFailure()),
      );
    });
  });
}
