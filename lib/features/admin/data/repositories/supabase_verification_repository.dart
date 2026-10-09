import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/data/models/verification_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseVerificationRepository implements VerificationRepository {
  SupabaseVerificationRepository(SupabaseClient client)
    : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<VerificationSummary>>> fetchQueue(
    VerificationStatus status, {
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_verifications', {
    'p_status': toWire(status),
    'p_limit': limit,
    'p_offset': offset,
  }, VerificationModels.queue);

  @override
  Future<Result<VerificationDetail>> fetchDetail(String verificationId) =>
      _rpc.call('admin_get_verification', {
        'p_verification_id': verificationId,
      }, VerificationModels.detail);

  @override
  Future<Result<void>> approve(String verificationId) => _rpc.run(
    'admin_approve_verification',
    {'p_verification_id': verificationId},
  );

  @override
  Future<Result<void>> reject(String verificationId, String reason) =>
      _rpc.run('admin_reject_verification', {
        'p_verification_id': verificationId,
        'p_reason': reason,
      });
}
