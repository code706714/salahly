import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/domain/repositories/withdrawal_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// The technicians' withdrawals, the ones waiting for the team first.
class WithdrawalsCubit extends PagedCubit<WithdrawalReview, WithdrawalFilter> {
  WithdrawalsCubit(this._repository) : super(const WithdrawalFilter());

  final WithdrawalReviewRepository _repository;

  @override
  Future<Result<PagedResult<WithdrawalReview>>> fetch(
    WithdrawalFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchWithdrawals(
    status: filter.status,
    limit: limit,
    offset: offset,
  );
}
