import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/data/models/escrow_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/domain/repositories/escrow_review_repository.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEscrowReviewRepository implements EscrowReviewRepository {
  SupabaseEscrowReviewRepository(this._client) : _rpc = AdminRpc(_client);

  final SupabaseClient _client;
  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<EscrowReview>>> fetchEscrows({
    required EscrowStatus? status,
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_escrows', {
    'p_status': status == null ? null : toWire(status),
    'p_limit': limit,
    'p_offset': offset,
  }, AdminEscrowModels.escrows);

  @override
  Future<Result<void>> approve(String escrowId) =>
      _rpc.run('admin_approve_escrow', {'p_escrow_id': escrowId});

  @override
  Future<Result<void>> reject(String escrowId, String reason) => _rpc.run(
    'admin_reject_escrow',
    {'p_escrow_id': escrowId, 'p_reason': reason},
  );

  @override
  Future<Result<void>> resolve(
    String escrowId, {
    required bool payTechnician,
    required String note,
  }) => _rpc.run('admin_resolve_escrow', {
    'p_escrow_id': escrowId,
    'p_pay_technician': payTechnician,
    'p_note': note,
  });

  @override
  Future<Result<void>> markRefunded(String escrowId, String reference) =>
      _rpc.run('admin_mark_escrow_refunded', {
        'p_escrow_id': escrowId,
        'p_reference': reference,
      });

  @override
  Future<Result<void>> refundOnline(String escrowId) async {
    try {
      await _client.functions.invoke(
        'payment-refund',
        body: {'escrow_id': escrowId},
      );
      return const Ok(null);
    } on FunctionException catch (error) {
      if (isNetworkError(error)) return const Err(NetworkFailure());
      final details = error.details;
      final name = details is Map ? details['error'] : null;
      return Err(switch (name) {
        'refund_by_dashboard' => const RefundByDashboardFailure(),
        'admin_required' => const AdminRequiredFailure(),
        'recent_login_required' => const RecentLoginRequiredFailure(),
        'not_refund_due' => const NotPendingFailure(),
        'escrow_not_found' => const AdminNotFoundFailure(),
        _ => UnexpectedFailure(error),
      });
    } on Object catch (error) {
      return Err(adminFailureFrom(error));
    }
  }
}
