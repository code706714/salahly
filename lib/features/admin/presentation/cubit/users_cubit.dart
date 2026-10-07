import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// Technicians or customers, newest first.
class UsersCubit extends PagedCubit<AdminUser, UserFilter> {
  UsersCubit(this._repository) : super(const UserFilter());

  final UsersRepository _repository;

  @override
  Future<Result<PagedResult<AdminUser>>> fetch(
    UserFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchUsers(filter, limit: limit, offset: offset);
}

/// Suspends and restores accounts.
class UserActionsCubit extends ActionCubit {
  UserActionsCubit(this._repository);

  final UsersRepository _repository;

  /// [reason] is 3 to 200 characters kept for the team.
  Future<void> suspend(String userId, String reason) => perform(
    () => _repository.suspend(userId, reason),
    outcome: AdminOutcome.userSuspended,
  );

  Future<void> restore(String userId) => perform(
    () => _repository.restore(userId),
    outcome: AdminOutcome.userRestored,
  );
}
