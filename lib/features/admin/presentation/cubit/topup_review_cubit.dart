import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';

/// Approves or rejects a transfer. Both need a sign in from the last 15
/// minutes; without one the failure is a `RecentLoginRequiredFailure` and
/// `retry` repeats the change after the admin signs in anew.
class TopupReviewCubit extends ActionCubit {
  TopupReviewCubit(this._repository);

  final TopupReviewRepository _repository;

  /// Adds the uses to the person's balance.
  Future<void> approve(String topupId) => perform(
    () => _repository.approve(topupId),
    outcome: AdminOutcome.topupApproved,
  );

  /// [reason] is what the person reads.
  Future<void> reject(String topupId, String reason) => perform(
    () => _repository.reject(topupId, reason),
    outcome: AdminOutcome.topupRejected,
  );
}
