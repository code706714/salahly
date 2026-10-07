import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/users_cubit.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

/// The paging rules every admin list shares, through the users list.
void main() {
  late MockUsersRepository repository;
  final first = testAdminTechnician();
  final second = testAdminTechnician(id: 'tech-2', name: 'مني كريم');

  setUpAll(AdminHarness.registerFallbacks);

  setUp(() {
    repository = MockUsersRepository();
    when(
      () => repository.fetchUsers(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Ok(PagedResult<AdminUser>(items: [first], total: 1)),
    );
  });

  void stubPage(int offset, PagedResult<AdminUser> page) => when(
    () => repository.fetchUsers(
      any(),
      limit: adminPageSize,
      offset: offset,
    ),
  ).thenAnswer((_) async => Ok(page));

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'shows loading, then the first page with the total',
    build: () => UsersCubit(repository),
    act: (cubit) => cubit.load(),
    expect: () => [
      const PagedState<AdminUser, UserFilter>(filter: UserFilter()),
      PagedState<AdminUser, UserFilter>(
        filter: const UserFilter(),
        items: [first],
        total: 1,
        isLoading: false,
      ),
    ],
    verify: (_) => verify(
      () => repository.fetchUsers(
        const UserFilter(),
        limit: adminPageSize,
        offset: 0,
      ),
    ).called(1),
  );

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'keeps the rows on screen while the next page loads',
    build: () => UsersCubit(repository),
    seed: () => PagedState<AdminUser, UserFilter>(
      filter: const UserFilter(),
      items: [first],
      total: 60,
      isLoading: false,
    ),
    act: (cubit) => cubit.goToPage(1),
    expect: () => [
      isA<PagedState<AdminUser, UserFilter>>()
          .having((state) => state.items, 'items', [first])
          .having((state) => state.isLoading, 'isLoading', true)
          .having((state) => state.page, 'page', 1),
      isA<PagedState<AdminUser, UserFilter>>()
          .having((state) => state.isLoading, 'isLoading', false)
          .having((state) => state.page, 'page', 1),
    ],
    verify: (_) => verify(
      () => repository.fetchUsers(
        any(),
        limit: adminPageSize,
        offset: adminPageSize,
      ),
    ).called(1),
  );

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'ignores a page that does not exist',
    build: () => UsersCubit(repository),
    seed: () => PagedState<AdminUser, UserFilter>(
      filter: const UserFilter(),
      items: [first],
      total: 10,
      isLoading: false,
    ),
    act: (cubit) async {
      await cubit.goToPage(-1);
      await cubit.goToPage(1);
    },
    expect: () => <Object>[],
    verify: (_) => verifyNever(
      () => repository.fetchUsers(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ),
  );

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'starts from the first page when the filter changes',
    build: () => UsersCubit(repository),
    seed: () => PagedState<AdminUser, UserFilter>(
      filter: const UserFilter(),
      items: [first],
      total: 60,
      page: 1,
      isLoading: false,
    ),
    act: (cubit) => cubit.filterChanged(
      const UserFilter(role: UserRole.consumer, search: 'نور'),
    ),
    verify: (cubit) {
      expect(cubit.state.page, 0);
      expect(cubit.state.filter.search, 'نور');
      verify(
        () => repository.fetchUsers(
          const UserFilter(role: UserRole.consumer, search: 'نور'),
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1);
    },
  );

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'does nothing when the filter is the same',
    build: () => UsersCubit(repository),
    act: (cubit) => cubit.filterChanged(const UserFilter()),
    expect: () => <Object>[],
  );

  blocTest<UsersCubit, PagedState<AdminUser, UserFilter>>(
    'says why a page could not load, keeping what was shown',
    setUp: () => when(
      () => repository.fetchUsers(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => UsersCubit(repository),
    seed: () => PagedState<AdminUser, UserFilter>(
      filter: const UserFilter(),
      items: [first],
      total: 1,
      isLoading: false,
    ),
    act: (cubit) => cubit.reload(),
    verify: (cubit) {
      expect(cubit.state.failure, const NetworkFailure());
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.items, [first]);
    },
  );

  test('drops an answer that arrives after a newer request', () async {
    final slow = Completer<Result<PagedResult<AdminUser>>>();
    when(
      () => repository.fetchUsers(
        const UserFilter(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => slow.future);
    when(
      () => repository.fetchUsers(
        const UserFilter(search: 'مني'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async => Ok(PagedResult<AdminUser>(items: [second], total: 1)),
    );
    final cubit = UsersCubit(repository);
    addTearDown(cubit.close);

    final stale = cubit.load();
    await cubit.filterChanged(const UserFilter(search: 'مني'));
    slow.complete(Ok(PagedResult<AdminUser>(items: [first], total: 1)));
    await stale;

    expect(cubit.state.items, [second]);
    expect(cubit.state.filter.search, 'مني');
  });

  test('steps back when the page it was on is gone', () async {
    stubPage(
      0,
      PagedResult<AdminUser>(items: [first], total: adminPageSize + 1),
    );
    stubPage(
      adminPageSize,
      PagedResult<AdminUser>(items: [second], total: adminPageSize + 1),
    );
    final cubit = UsersCubit(repository);
    addTearDown(cubit.close);
    await cubit.goToPage(0);
    await cubit.goToPage(1);
    expect(cubit.state.items, [second]);

    // The row on the second page was removed meanwhile.
    stubPage(
      adminPageSize,
      const PagedResult<AdminUser>(items: [], total: adminPageSize),
    );
    stubPage(0, PagedResult<AdminUser>(items: [first], total: adminPageSize));
    await cubit.reload();

    expect(cubit.state.page, 0);
    expect(cubit.state.items, [first]);
    expect(cubit.state.total, adminPageSize);
  });

  test('counts pages and knows its neighbours', () {
    const state = PagedState<AdminUser, UserFilter>(
      filter: UserFilter(),
      total: adminPageSize * 2 + 1,
      page: 1,
      isLoading: false,
    );
    expect(state.pageCount, 3);
    expect(state.hasPrevious, isTrue);
    expect(state.hasNext, isTrue);
    expect(state.copyWith(page: 2).hasNext, isFalse);
    expect(state.isEmpty, isTrue);
  });
}
