import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/escrow_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// The guaranteed payments, the ones waiting for the team first.
class EscrowsCubit extends PagedCubit<EscrowReview, EscrowFilter> {
  EscrowsCubit(this._repository) : super(const EscrowFilter());

  final EscrowReviewRepository _repository;

  @override
  Future<Result<PagedResult<EscrowReview>>> fetch(
    EscrowFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchEscrows(
    status: filter.status,
    limit: limit,
    offset: offset,
  );
}
