import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/escrow_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/escrows_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockEscrowReviewRepository repository;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() => repository = MockEscrowReviewRepository());

  group('EscrowsCubit', () {
    setUp(
      () =>
          when(
            () => repository.fetchEscrows(
              status: any(named: 'status'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(PagedResult(items: [testEscrowReview()], total: 1)),
          ),
    );

    blocTest<EscrowsCubit, PagedState<EscrowReview, EscrowFilter>>(
      'starts with the transfers waiting to be checked',
      build: () => EscrowsCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testEscrowReview()]);
        verify(
          () => repository.fetchEscrows(
            status: EscrowStatus.pending,
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<EscrowsCubit, PagedState<EscrowReview, EscrowFilter>>(
      'narrows the list by status',
      build: () => EscrowsCubit(repository),
      act: (cubit) => cubit.filterChanged(
        const EscrowFilter(status: EscrowStatus.disputed),
      ),
      verify: (_) => verify(
        () => repository.fetchEscrows(
          status: EscrowStatus.disputed,
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1),
    );
  });

  group('EscrowReviewCubit', () {
    blocTest<EscrowReviewCubit, ActionState>(
      'approves a transfer',
      setUp: () => when(
        () => repository.approve('escrow-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => EscrowReviewCubit(repository),
      act: (cubit) => cubit.approve('escrow-1'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.escrowApproved),
      ],
    );

    blocTest<EscrowReviewCubit, ActionState>(
      'rejects a transfer with the reason the consumer reads',
      setUp: () => when(
        () => repository.reject('escrow-1', 'المبلغ ناقص'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => EscrowReviewCubit(repository),
      act: (cubit) => cubit.reject('escrow-1', 'المبلغ ناقص'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.escrowRejected),
      ],
    );

    blocTest<EscrowReviewCubit, ActionState>(
      'records a payout',
      setUp: () => when(
        () => repository.markPaid('escrow-1', 'IP-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => EscrowReviewCubit(repository),
      act: (cubit) => cubit.markPaid('escrow-1', 'IP-1'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.escrowPaid),
      ],
    );

    blocTest<EscrowReviewCubit, ActionState>(
      'settles a dispute',
      setUp: () => when(
        () => repository.resolve(
          'escrow-1',
          payTechnician: true,
          note: 'الفني على حق',
        ),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => EscrowReviewCubit(repository),
      act: (cubit) => cubit.resolve(
        'escrow-1',
        payTechnician: true,
        note: 'الفني على حق',
      ),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.escrowResolved),
      ],
    );

    blocTest<EscrowReviewCubit, ActionState>(
      'records a refund',
      setUp: () => when(
        () => repository.markRefunded('escrow-1', 'IP-2'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => EscrowReviewCubit(repository),
      act: (cubit) => cubit.markRefunded('escrow-1', 'IP-2'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.escrowRefunded),
      ],
    );

    blocTest<EscrowReviewCubit, ActionState>(
      'repeats the step after a fresh sign in',
      setUp: () {
        var tries = 0;
        when(() => repository.approve('escrow-1')).thenAnswer(
          (_) async => ++tries == 1
              ? const Err(RecentLoginRequiredFailure())
              : const Ok(null),
        );
      },
      build: () => EscrowReviewCubit(repository),
      act: (cubit) async {
        await cubit.approve('escrow-1');
        await cubit.retry();
      },
      verify: (cubit) {
        expect(cubit.state.outcome, AdminOutcome.escrowApproved);
        verify(() => repository.approve('escrow-1')).called(2);
      },
    );
  });
}
