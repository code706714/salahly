import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/data/models/audit_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/audit_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuditRepository implements AuditRepository {
  SupabaseAuditRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<AuditEntry>>> fetchLog(
    AuditFilter filter, {
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_audit_log', {
    'p_action': filter.action,
    'p_target_id': filter.targetId.trim().isEmpty
        ? null
        : filter.targetId.trim(),
    'p_limit': limit,
    'p_offset': offset,
  }, AuditModels.log);
}
