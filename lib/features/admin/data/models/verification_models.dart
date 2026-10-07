import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';

/// Maps what the `admin_*verification*` functions return.
abstract final class VerificationModels {
  static PagedResult<VerificationSummary> queue(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [
          for (final item in listFromWire(json['items'])) _summary(item),
        ],
      );

  static VerificationSummary _summary(Map<String, dynamic> json) =>
      VerificationSummary(
        verificationId: json['verification_id'] as String,
        technicianId: json['technician_id'] as String,
        name: json['name'] as String,
        areaId: json['area_id'] as String,
        areaName: json['area_name'] as String,
        status: enumFromWire(VerificationStatus.values, json['status']),
        submittedAt: timeFromWire(json['submitted_at']),
        reviewedAt: optionalTimeFromWire(json['reviewed_at']),
        rejectionReason: json['rejection_reason'] as String?,
        suspended: json['suspended'] as bool,
      );

  static VerificationDetail detail(Map<String, dynamic> json) =>
      VerificationDetail(
        verificationId: json['verification_id'] as String,
        technicianId: json['technician_id'] as String,
        status: enumFromWire(VerificationStatus.values, json['status']),
        submittedAt: timeFromWire(json['submitted_at']),
        reviewedAt: optionalTimeFromWire(json['reviewed_at']),
        rejectionReason: json['rejection_reason'] as String?,
        idFrontPath: json['id_front_path'] as String,
        idBackPath: json['id_back_path'] as String,
        selfiePath: json['selfie_path'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        phoneConfirmed: json['phone_confirmed'] as bool,
        shopName: json['shop_name'] as String?,
        yearsExperience: intOf(json['years_experience']),
        area: NamedArea(
          id: json['area_id'] as String,
          name: json['area_name'] as String,
        ),
        serviceRadiusKm: intOf(json['service_radius_km']),
        workDays: {
          for (final day in json['work_days'] as List<Object?>) intOf(day),
        },
        suspended: json['suspended'] as bool,
        previousAttempts: intOf(json['previous_attempts']),
        areas: [
          for (final area in listFromWire(json['areas']))
            NamedArea(
              id: area['id'] as String,
              name: area['name_ar'] as String,
            ),
        ],
        services: [
          for (final service in listFromWire(json['services']))
            OfferedService(
              serviceId: service['service_id'] as String,
              name: service['name_ar'] as String,
              startingPricePiastres: intOf(service['starting_price_piastres']),
            ),
        ],
      );
}
