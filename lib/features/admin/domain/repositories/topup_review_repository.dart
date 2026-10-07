import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

abstract interface class TopupReviewRepository {
  /// A null [status] or [role] lists every one.
  Future<Result<PagedResult<TopupReview>>> fetchTopups({
    required TopupStatus? status,
    required UserRole? role,
    required int limit,
    required int offset,
  });

  /// Adds the uses to the person's balance, once.
  Future<Result<void>> approve(String topupId);

  /// [reason] is 3 to 200 characters the person can read.
  Future<Result<void>> reject(String topupId, String reason);
}
