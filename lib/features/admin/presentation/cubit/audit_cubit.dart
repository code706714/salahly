import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/audit_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// What the admins did, newest first.
class AuditCubit extends PagedCubit<AuditEntry, AuditFilter> {
  AuditCubit(this._repository) : super(const AuditFilter());

  final AuditRepository _repository;

  @override
  Future<Result<PagedResult<AuditEntry>>> fetch(
    AuditFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchLog(filter, limit: limit, offset: offset);
}
