import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';

/// Maps the `profiles` row with its embedded side profiles, as selected by
/// [UserProfileModel.select], to the domain entity. The same JSON is what
/// the device cache stores.
abstract final class UserProfileModel {
  static const select =
      'id, phone, full_name, active_role, '
      'consumer_profiles(honorific, request_credits, area_id, '
      'service_areas(name_ar)), '
      'technician_profiles(verification_status, job_credits)';

  static UserProfile fromJson(Map<String, dynamic> json) {
    final consumer = json['consumer_profiles'] as Map<String, dynamic>?;
    final technician = json['technician_profiles'] as Map<String, dynamic>?;
    return UserProfile(
      id: json['id'] as String,
      phone: json['phone'] as String,
      fullName: json['full_name'] as String,
      activeRole: UserRole.values.byName(json['active_role'] as String),
      consumer: consumer == null ? null : _consumerFromJson(consumer),
      technician: technician == null ? null : _technicianFromJson(technician),
    );
  }

  static ConsumerProfile _consumerFromJson(Map<String, dynamic> json) {
    final area = json['service_areas'] as Map<String, dynamic>;
    return ConsumerProfile(
      honorific: Honorific.values.byName(json['honorific'] as String),
      areaId: json['area_id'] as String,
      areaName: area['name_ar'] as String,
      requestCredits: json['request_credits'] as int,
    );
  }

  static TechnicianProfile _technicianFromJson(Map<String, dynamic> json) {
    return TechnicianProfile(
      verificationStatus: VerificationStatus.values.byName(
        json['verification_status'] as String,
      ),
      jobCredits: json['job_credits'] as int,
    );
  }
}
