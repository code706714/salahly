import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/withdrawal_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/domain/repositories/withdrawal_review_repository.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseWithdrawalReviewRepository implements WithdrawalReviewRepository {
  SupabaseWithdrawalReviewRepository(SupabaseClient client)
    : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<WithdrawalReview>>> fetchWithdrawals({
    required WithdrawalStatus? status,
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_withdrawals', {
    'p_status': status == null ? null : toWire(status),
    'p_limit': limit,
    'p_offset': offset,
  }, AdminWithdrawalModels.withdrawals);

  @override
  Future<Result<void>> markPaid(String withdrawalId, String reference) =>
      _rpc.run('admin_mark_withdrawal_paid', {
        'p_withdrawal_id': withdrawalId,
        'p_reference': reference,
      });

  @override
  Future<Result<void>> reject(String withdrawalId, String reason) => _rpc.run(
    'admin_reject_withdrawal',
    {'p_withdrawal_id': withdrawalId, 'p_reason': reason},
  );
}
