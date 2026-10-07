import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/data/models/topup_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTopupReviewRepository implements TopupReviewRepository {
  SupabaseTopupReviewRepository(SupabaseClient client)
    : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<TopupReview>>> fetchTopups({
    required TopupStatus? status,
    required UserRole? role,
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_topups', {
    'p_status': status == null ? null : toWire(status),
    'p_role': role == null ? null : toWire(role),
    'p_limit': limit,
    'p_offset': offset,
  }, TopupModels.topups);

  @override
  Future<Result<void>> approve(String topupId) =>
      _rpc.run('admin_approve_topup', {'p_topup_id': topupId});

  @override
  Future<Result<void>> reject(String topupId, String reason) => _rpc.run(
    'admin_reject_topup',
    {'p_topup_id': topupId, 'p_reason': reason},
  );
}
