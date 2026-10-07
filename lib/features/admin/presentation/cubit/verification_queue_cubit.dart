import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// The technicians' ID submissions with one status; the waiting ones come
/// oldest first.
class VerificationQueueCubit
    extends PagedCubit<VerificationSummary, VerificationStatus> {
  VerificationQueueCubit(this._repository) : super(VerificationStatus.pending);

  final VerificationRepository _repository;

  @override
  Future<Result<PagedResult<VerificationSummary>>> fetch(
    VerificationStatus filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchQueue(filter, limit: limit, offset: offset);
}
