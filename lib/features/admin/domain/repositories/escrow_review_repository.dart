import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

abstract interface class EscrowReviewRepository {
  /// A null [status] lists every one.
  Future<Result<PagedResult<EscrowReview>>> fetchEscrows({
    required EscrowStatus? status,
    required int limit,
    required int offset,
  });

  /// The transfer was found in Salahly's account: the money is held.
  Future<Result<void>> approve(String escrowId);

  /// The transfer was not found; [reason] is what the consumer reads.
  Future<Result<void>> reject(String escrowId, String reason);

  /// The technician was paid; [reference] is the transfer's reference.
  Future<Result<void>> markPaid(String escrowId, String reference);

  /// Settles a dispute: the technician is paid, or the consumer gets the
  /// money back. [note] says why.
  Future<Result<void>> resolve(
    String escrowId, {
    required bool payTechnician,
    required String note,
  });

  /// The consumer got her money back; [reference] is the transfer's
  /// reference.
  Future<Result<void>> markRefunded(String escrowId, String reference);

  /// Asks the payment provider to return an online payment to the consumer.
  /// Fails with `RefundByDashboardFailure` when the provider can't do it
  /// through the API: the refund is then made in the provider's dashboard and
  /// closes the guarantee by itself.
  Future<Result<void>> refundOnline(String escrowId);
}
