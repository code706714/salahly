import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

abstract interface class WithdrawalReviewRepository {
  /// A null [status] lists every one.
  Future<Result<PagedResult<WithdrawalReview>>> fetchWithdrawals({
    required WithdrawalStatus? status,
    required int limit,
    required int offset,
  });

  /// The money was sent; [reference] is the transfer's reference.
  Future<Result<void>> markPaid(String withdrawalId, String reference);

  /// The money can't be sent; it returns to the wallet and the technician
  /// reads [reason].
  Future<Result<void>> reject(String withdrawalId, String reason);
}
