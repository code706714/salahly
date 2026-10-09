import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/user_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUsersRepository implements UsersRepository {
  SupabaseUsersRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<AdminUser>>> fetchUsers(
    UserFilter filter, {
    required int limit,
    required int offset,
  }) => _rpc.call(
    'admin_list_users',
    {
      'p_role': toWire(filter.role),
      'p_search': filter.search.trim().isEmpty ? null : filter.search.trim(),
      'p_area_id': filter.areaId,
      'p_status': filter.status == null ? null : toWire(filter.status!),
      'p_limit': limit,
      'p_offset': offset,
    },
    (json) => UserModels.users(json, role: filter.role),
  );

  @override
  Future<Result<void>> suspend(String userId, String reason) => _rpc.run(
    'admin_suspend_user',
    {'p_user_id': userId, 'p_reason': reason},
  );

  @override
  Future<Result<void>> restore(String userId) =>
      _rpc.run('admin_restore_user', {'p_user_id': userId});
}
