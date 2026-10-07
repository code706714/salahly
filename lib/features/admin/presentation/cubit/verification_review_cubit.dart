import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';

/// Approves or rejects one technician's ID submission.
class VerificationReviewCubit extends ActionCubit {
  VerificationReviewCubit(this._repository, {required this.verificationId});

  final VerificationRepository _repository;
  final String verificationId;

  Future<void> approve() => perform(
    () => _repository.approve(verificationId),
    outcome: AdminOutcome.verificationApproved,
  );

  /// [reason] is what the technician reads.
  Future<void> reject(String reason) => perform(
    () => _repository.reject(verificationId, reason),
    outcome: AdminOutcome.verificationRejected,
  );
}
