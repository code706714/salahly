import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/account/data/models/user_profile_model.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';

Map<String, dynamic> _technicianRow({String status = 'pending'}) => {
  'id': '0c9d8e7f-1a2b-4c3d-8e9f-a0b1c2d3e4f5',
  'phone': '+201112345678',
  'full_name': 'محمود السيد',
  'active_role': 'technician',
  'consumer_profiles': null,
  'technician_profiles': {
    'verification_status': status,
    'job_credits': 2,
  },
};

void main() {
  group('UserProfileModel.fromJson', () {
    test('reads a consumer with the name of their area', () {
      final profile = UserProfileModel.fromJson({
        'id': '5b1f5c2e-6a43-4d1b-9a0e-2f7c8d9e0a11',
        'phone': '+201002345678',
        'full_name': 'منى عبد الرحمن',
        'active_role': 'consumer',
        'consumer_profiles': {
          'honorific': 'ms',
          'request_credits': 2,
          'area_id': 'nasr_city',
          'service_areas': {'name_ar': 'مدينة نصر'},
        },
        'technician_profiles': null,
      });

      expect(
        profile,
        const UserProfile(
          id: '5b1f5c2e-6a43-4d1b-9a0e-2f7c8d9e0a11',
          phone: '+201002345678',
          fullName: 'منى عبد الرحمن',
          activeRole: UserRole.consumer,
          consumer: ConsumerProfile(
            honorific: Honorific.ms,
            areaId: 'nasr_city',
            areaName: 'مدينة نصر',
            requestCredits: 2,
          ),
        ),
      );
    });

    test('reads a technician awaiting verification', () {
      expect(
        UserProfileModel.fromJson(_technicianRow()),
        const UserProfile(
          id: '0c9d8e7f-1a2b-4c3d-8e9f-a0b1c2d3e4f5',
          phone: '+201112345678',
          fullName: 'محمود السيد',
          activeRole: UserRole.technician,
          technician: TechnicianProfile(
            verificationStatus: VerificationStatus.pending,
            jobCredits: 2,
          ),
        ),
      );
    });

    test('reads someone who has both side profiles', () {
      final profile = UserProfileModel.fromJson({
        ..._technicianRow(),
        'consumer_profiles': {
          'honorific': 'mr',
          'request_credits': 0,
          'area_id': 'maadi',
          'service_areas': {'name_ar': 'المعادي'},
        },
      });

      expect(profile.activeRole, UserRole.technician);
      expect(
        profile.consumer,
        const ConsumerProfile(
          honorific: Honorific.mr,
          areaId: 'maadi',
          areaName: 'المعادي',
          requestCredits: 0,
        ),
      );
      expect(profile.technician, isNotNull);
    });

    test('treats missing side profiles as not onboarded on that side', () {
      final profile = UserProfileModel.fromJson({
        'id': '5b1f5c2e-6a43-4d1b-9a0e-2f7c8d9e0a11',
        'phone': '+201002345678',
        'full_name': 'منى عبد الرحمن',
        'active_role': 'consumer',
      });

      expect(profile.consumer, isNull);
      expect(profile.technician, isNull);
    });

    test('reads every verification status the database defines', () {
      const statuses = {
        'pending': VerificationStatus.pending,
        'approved': VerificationStatus.approved,
        'rejected': VerificationStatus.rejected,
      };

      for (final MapEntry(key: column, value: status) in statuses.entries) {
        final profile = UserProfileModel.fromJson(
          _technicianRow(status: column),
        );
        expect(profile.technician?.verificationStatus, status, reason: column);
      }
    });

    test('rejects a role the app does not know', () {
      expect(
        () => UserProfileModel.fromJson({
          ..._technicianRow(),
          'active_role': 'admin',
        }),
        throwsArgumentError,
      );
    });
  });
}
