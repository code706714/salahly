import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/audit_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/users_cubit.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  setUpAll(AdminHarness.registerFallbacks);

  group('UsersCubit', () {
    late MockUsersRepository repository;
    setUp(() => repository = MockUsersRepository());

    blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
      'starts with the technicians',
      setUp: () =>
          when(
            () => repository.fetchUsers(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(
              PagedResult<AdminUser>(items: [testAdminTechnician()], total: 1),
            ),
          ),
      build: () => UsersCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testAdminTechnician()]);
        verify(
          () => repository.fetchUsers(
            const UserFilter(),
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    group('UserActionsCubit', () {
      blocTest<UserActionsCubit, ActionState>(
        'suspends an account with the reason kept for the team',
        setUp: () => when(
          () => repository.suspend('tech-1', 'شكاوي متكررة'),
        ).thenAnswer((_) async => const Ok(null)),
        build: () => UserActionsCubit(repository),
        act: (cubit) => cubit.suspend('tech-1', 'شكاوي متكررة'),
        expect: () => const [
          ActionState(isBusy: true),
          ActionState(completed: 1, outcome: AdminOutcome.userSuspended),
        ],
      );

      blocTest<UserActionsCubit, ActionState>(
        'restores an account',
        setUp: () => when(
          () => repository.restore('tech-1'),
        ).thenAnswer((_) async => const Ok(null)),
        build: () => UserActionsCubit(repository),
        act: (cubit) => cubit.restore('tech-1'),
        expect: () => const [
          ActionState(isBusy: true),
          ActionState(completed: 1, outcome: AdminOutcome.userRestored),
        ],
      );

      blocTest<UserActionsCubit, ActionState>(
        'refuses to suspend an admin',
        setUp: () => when(
          () => repository.suspend(any(), any()),
        ).thenAnswer((_) async => const Err(CannotSuspendAdminFailure())),
        build: () => UserActionsCubit(repository),
        act: (cubit) => cubit.suspend('admin-2', 'سبب'),
        expect: () => const [
          ActionState(isBusy: true),
          ActionState(failure: CannotSuspendAdminFailure()),
        ],
      );
    });

    blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
      'drops the status of the other tab when the role changes',
      setUp: () =>
          when(
            () => repository.fetchUsers(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => const Ok(PagedResult<AdminUser>(items: [], total: 0)),
          ),
      build: () => UsersCubit(repository),
      seed: () => const PagedState<AdminUser, UserFilter>(
        filter: UserFilter(status: AccountStatus.verified),
        isLoading: false,
      ),
      act: (cubit) => cubit.filterChanged(
        cubit.state.filter.withRole(UserRole.consumer),
      ),
      verify: (cubit) => expect(
        cubit.state.filter,
        const UserFilter(role: UserRole.consumer),
      ),
    );
  });

  group('AuditCubit', () {
    late MockAuditRepository repository;
    setUp(() => repository = MockAuditRepository());

    blocTest<AuditCubit, PagedState<AuditEntry, AuditFilter>>(
      'loads the log and narrows it by action and target',
      setUp: () =>
          when(
            () => repository.fetchLog(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(PagedResult(items: [testAuditEntry()], total: 1)),
          ),
      build: () => AuditCubit(repository),
      act: (cubit) async {
        await cubit.load();
        await cubit.filterChanged(
          const AuditFilter(action: 'approve_topup', targetId: 'topup-1'),
        );
      },
      verify: (_) {
        verify(
          () => repository.fetchLog(
            const AuditFilter(),
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
        verify(
          () => repository.fetchLog(
            const AuditFilter(action: 'approve_topup', targetId: 'topup-1'),
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );
  });
}
