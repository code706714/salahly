import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';

abstract interface class UsersRepository {
  Future<Result<PagedResult<AdminUser>>> fetchUsers(
    UserFilter filter, {
    required int limit,
    required int offset,
  });

  /// [reason] is 3 to 200 characters kept for the team.
  Future<Result<void>> suspend(String userId, String reason);

  Future<Result<void>> restore(String userId);
}
