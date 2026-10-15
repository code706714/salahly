import 'package:salahly/features/admin/domain/repositories/escrow_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';

/// Moves a guaranteed payment along. Every step needs a sign in from the
/// last 15 minutes; without one the failure is a `RecentLoginRequiredFailure`
/// and `retry` repeats the step after the admin signs in anew.
class EscrowReviewCubit extends ActionCubit {
  EscrowReviewCubit(this._repository);

  final EscrowReviewRepository _repository;

  /// The transfer is in Salahly's account: the money is held.
  Future<void> approve(String escrowId) => perform(
    () => _repository.approve(escrowId),
    outcome: AdminOutcome.escrowApproved,
  );

  /// [reason] is what the consumer reads.
  Future<void> reject(String escrowId, String reason) => perform(
    () => _repository.reject(escrowId, reason),
    outcome: AdminOutcome.escrowRejected,
  );

  /// The technician was paid by the transfer named [reference].
  Future<void> markPaid(String escrowId, String reference) => perform(
    () => _repository.markPaid(escrowId, reference),
    outcome: AdminOutcome.escrowPaid,
  );

  /// Settles a dispute for the technician or for the consumer.
  Future<void> resolve(
    String escrowId, {
    required bool payTechnician,
    required String note,
  }) => perform(
    () => _repository.resolve(
      escrowId,
      payTechnician: payTechnician,
      note: note,
    ),
    outcome: AdminOutcome.escrowResolved,
  );

  /// The consumer got her money back by the transfer named [reference].
  Future<void> markRefunded(String escrowId, String reference) => perform(
    () => _repository.markRefunded(escrowId, reference),
    outcome: AdminOutcome.escrowRefunded,
  );

  /// Returns an online payment to the consumer through the provider.
  Future<void> refundOnline(String escrowId) => perform(
    () => _repository.refundOnline(escrowId),
    outcome: AdminOutcome.escrowRefunded,
  );
}
