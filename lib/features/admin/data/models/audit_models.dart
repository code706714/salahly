import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';

/// Maps what `admin_list_audit_log` returns.
abstract final class AuditModels {
  static PagedResult<AuditEntry> log(Map<String, dynamic> json) => PagedResult(
    total: intOf(json['total']),
    items: [
      for (final item in listFromWire(json['items']))
        AuditEntry(
          id: intOf(item['id']),
          adminId: item['admin_id'] as String,
          adminName: item['admin_name'] as String?,
          action: item['action'] as String,
          targetType: item['target_type'] as String,
          targetId: item['target_id'] as String?,
          details: (item['details'] as Map<String, dynamic>?) ?? const {},
          createdAt: timeFromWire(item['created_at']),
        ),
    ],
  );
}
