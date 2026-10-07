import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';

/// Maps what `admin_list_users` returns.
abstract final class UserModels {
  static PagedResult<AdminUser> users(
    Map<String, dynamic> json, {
    required UserRole role,
  }) => PagedResult(
    total: intOf(json['total']),
    items: [
      for (final item in listFromWire(json['items']))
        switch (role) {
          UserRole.technician => _technician(item),
          UserRole.consumer => _consumer(item),
        },
    ],
  );

  static AdminTechnician _technician(Map<String, dynamic> json) =>
      AdminTechnician(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        areaId: json['area_id'] as String,
        areaName: json['area_name'] as String,
        status: enumFromWire(AccountStatus.values, json['status']),
        verificationStatus: enumFromWire(
          VerificationStatus.values,
          json['verification_status'],
        ),
        balance: intOf(json['balance']),
        pendingTopup: json['pending_topup'] as bool,
        createdAt: timeFromWire(json['created_at']),
        lastSignInAt: optionalTimeFromWire(json['last_sign_in_at']),
        suspensionReason: json['suspension_reason'] as String?,
        rating: optionalDoubleOf(json['rating']),
        reviewCount: intOf(json['review_count']),
        platformJobs: intOf(json['platform_jobs']),
      );

  static AdminConsumer _consumer(Map<String, dynamic> json) => AdminConsumer(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    areaId: json['area_id'] as String,
    areaName: json['area_name'] as String,
    status: enumFromWire(AccountStatus.values, json['status']),
    balance: intOf(json['balance']),
    pendingTopup: json['pending_topup'] as bool,
    createdAt: timeFromWire(json['created_at']),
    lastSignInAt: optionalTimeFromWire(json['last_sign_in_at']),
    suspensionReason: json['suspension_reason'] as String?,
    requestsCount: intOf(json['requests_count']),
    lastRequestAt: optionalTimeFromWire(json['last_request_at']),
    complaintsCount: intOf(json['complaints_count']),
  );
}
