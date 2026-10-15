import 'package:salahly/features/admin/domain/repositories/withdrawal_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';

/// Moves a withdrawal along. Every step needs a sign in from the last 15
/// minutes; without one the failure is a `RecentLoginRequiredFailure` and
/// `retry` repeats the step after the admin signs in anew.
class WithdrawalReviewCubit extends ActionCubit {
  WithdrawalReviewCubit(this._repository);

  final WithdrawalReviewRepository _repository;

  /// The money was sent by the transfer named [reference].
  Future<void> markPaid(String withdrawalId, String reference) => perform(
    () => _repository.markPaid(withdrawalId, reference),
    outcome: AdminOutcome.withdrawalPaid,
  );

  /// The money can't be sent; [reason] is what the technician reads.
  Future<void> reject(String withdrawalId, String reason) => perform(
    () => _repository.reject(withdrawalId, reason),
    outcome: AdminOutcome.withdrawalRejected,
  );
}
