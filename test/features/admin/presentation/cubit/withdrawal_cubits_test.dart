import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/withdrawal_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/withdrawals_cubit.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockWithdrawalReviewRepository repository;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() => repository = MockWithdrawalReviewRepository());

  group('WithdrawalsCubit', () {
    setUp(
      () =>
          when(
            () => repository.fetchWithdrawals(
              status: any(named: 'status'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async =>
                Ok(PagedResult(items: [testWithdrawalReview()], total: 1)),
          ),
    );

    blocTest<WithdrawalsCubit, PagedState<WithdrawalReview, WithdrawalFilter>>(
      'starts with the requests waiting for a transfer',
      build: () => WithdrawalsCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testWithdrawalReview()]);
        verify(
          () => repository.fetchWithdrawals(
            status: WithdrawalStatus.requested,
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<WithdrawalsCubit, PagedState<WithdrawalReview, WithdrawalFilter>>(
      'narrows the list by status',
      build: () => WithdrawalsCubit(repository),
      act: (cubit) => cubit.filterChanged(
        const WithdrawalFilter(status: WithdrawalStatus.paid),
      ),
      verify: (_) => verify(
        () => repository.fetchWithdrawals(
          status: WithdrawalStatus.paid,
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1),
    );
  });

  group('WithdrawalReviewCubit', () {
    blocTest<WithdrawalReviewCubit, ActionState>(
      'records the transfer',
      setUp: () => when(
        () => repository.markPaid('w-1', 'IP-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => WithdrawalReviewCubit(repository),
      act: (cubit) => cubit.markPaid('w-1', 'IP-1'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.withdrawalPaid),
      ],
    );

    blocTest<WithdrawalReviewCubit, ActionState>(
      'rejects with a reason',
      setUp: () => when(
        () => repository.reject('w-1', 'الرقم غلط'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => WithdrawalReviewCubit(repository),
      act: (cubit) => cubit.reject('w-1', 'الرقم غلط'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.withdrawalRejected),
      ],
    );

    blocTest<WithdrawalReviewCubit, ActionState>(
      'asks for a fresh sign in',
      setUp: () => when(
        () => repository.markPaid(any(), any()),
      ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure())),
      build: () => WithdrawalReviewCubit(repository),
      act: (cubit) => cubit.markPaid('w-1', 'IP-1'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(failure: RecentLoginRequiredFailure()),
      ],
    );
  });
}
