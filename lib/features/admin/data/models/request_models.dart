import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

/// Maps what `admin_list_requests` and `admin_list_complaints` return.
abstract final class RequestModels {
  static PagedResult<AdminRequest> requests(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [for (final item in listFromWire(json['items'])) _request(item)],
      );

  static AdminRequest _request(Map<String, dynamic> json) => AdminRequest(
    id: json['id'] as String,
    code: json['code'] as String,
    createdAt: timeFromWire(json['created_at']),
    issue: enumFromWire(RequestIssue.values, json['issue']),
    areaId: json['area_id'] as String,
    areaName: json['area_name'] as String,
    consumerName: json['consumer_name'] as String,
    technicianName: json['technician_name'] as String?,
    offerCount: intOf(json['offer_count']),
    status: enumFromWire(AdminRequestStatus.values, json['status']),
    stars: optionalIntOf(json['stars']),
    hasOpenComplaint: json['has_open_complaint'] as bool,
    hasComplaint: json['has_complaint'] as bool,
  );

  static PagedResult<AdminComplaint> complaints(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [
          for (final item in listFromWire(json['items'])) _complaint(item),
        ],
      );

  static AdminComplaint _complaint(Map<String, dynamic> json) => AdminComplaint(
    id: json['id'] as String,
    requestId: json['request_id'] as String,
    requestCode: json['request_code'] as String,
    reason: enumFromWire(ComplaintReason.values, json['reason']),
    details: json['details'] as String?,
    photoPath: json['photo_path'] as String?,
    createdAt: timeFromWire(json['created_at']),
    resolvedAt: optionalTimeFromWire(json['resolved_at']),
    resolutionNote: json['resolution_note'] as String?,
    issue: enumFromWire(RequestIssue.values, json['issue']),
    areaId: json['area_id'] as String,
    consumer: _party(json['consumer']! as Map<String, dynamic>),
    technician: _party(json['technician']! as Map<String, dynamic>),
  );

  static ComplaintParty _party(Map<String, dynamic> json) => ComplaintParty(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    suspended: json['suspended'] as bool? ?? false,
  );
}
