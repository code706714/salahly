import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';

// An interface so screens can be tested without a server.
// ignore: one_member_abstracts
abstract interface class AuditRepository {
  /// Newest first.
  Future<Result<PagedResult<AuditEntry>>> fetchLog(
    AuditFilter filter, {
    required int limit,
    required int offset,
  });
}
