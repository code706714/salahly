import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// The transfers people sent, waiting ones first by default, oldest first.
class TopupsCubit extends PagedCubit<TopupReview, TopupFilter> {
  TopupsCubit(this._repository) : super(const TopupFilter());

  final TopupReviewRepository _repository;

  @override
  Future<Result<PagedResult<TopupReview>>> fetch(
    TopupFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchTopups(
    status: filter.status,
    role: filter.role,
    limit: limit,
    offset: offset,
  );
}
