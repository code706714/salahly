import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';

abstract interface class VerificationRepository {
  Future<Result<PagedResult<VerificationSummary>>> fetchQueue(
    VerificationStatus status, {
    required int limit,
    required int offset,
  });

  /// Opening a submission is recorded in the audit log.
  Future<Result<VerificationDetail>> fetchDetail(String verificationId);

  Future<Result<void>> approve(String verificationId);

  /// [reason] is 3 to 200 characters the technician can read.
  Future<Result<void>> reject(String verificationId, String reason);
}
