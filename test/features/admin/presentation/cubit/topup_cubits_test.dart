import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/topup_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/topups_cubit.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockTopupReviewRepository repository;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() => repository = MockTopupReviewRepository());

  group('TopupsCubit', () {
    setUp(
      () =>
          when(
            () => repository.fetchTopups(
              status: any(named: 'status'),
              role: any(named: 'role'),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(PagedResult(items: [testTopupReview()], total: 1)),
          ),
    );

    blocTest<TopupsCubit, PagedState<TopupReview, TopupFilter>>(
      'starts with the waiting transfers of both sides',
      build: () => TopupsCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.items, [testTopupReview()]);
        verify(
          () => repository.fetchTopups(
            status: TopupStatus.pending,
            role: null,
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<TopupsCubit, PagedState<TopupReview, TopupFilter>>(
      'narrows the list by status and side',
      build: () => TopupsCubit(repository),
      act: (cubit) => cubit.filterChanged(
        const TopupFilter(status: null, role: UserRole.technician),
      ),
      verify: (_) => verify(
        () => repository.fetchTopups(
          status: null,
          role: UserRole.technician,
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1),
    );
  });

  group('TopupReviewCubit', () {
    blocTest<TopupReviewCubit, ActionState>(
      'approves a transfer',
      setUp: () => when(
        () => repository.approve('topup-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => TopupReviewCubit(repository),
      act: (cubit) => cubit.approve('topup-1'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.topupApproved),
      ],
    );

    blocTest<TopupReviewCubit, ActionState>(
      'rejects a transfer with the reason the person will read',
      setUp: () => when(
        () => repository.reject('topup-1', 'المبلغ مش مظبوط'),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => TopupReviewCubit(repository),
      act: (cubit) => cubit.reject('topup-1', 'المبلغ مش مظبوط'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.topupRejected),
      ],
    );

    test('approves again once the admin signed in anew', () async {
      var signedInRecently = false;
      when(() => repository.approve('topup-1')).thenAnswer(
        (_) async => signedInRecently
            ? const Ok(null)
            : const Err(RecentLoginRequiredFailure()),
      );
      final cubit = TopupReviewCubit(repository);
      addTearDown(cubit.close);

      await cubit.approve('topup-1');
      expect(cubit.state.failure, const RecentLoginRequiredFailure());
      expect(cubit.state.completed, 0);

      signedInRecently = true;
      await cubit.retry();

      expect(cubit.state.failure, isNull);
      expect(cubit.state.completed, 1);
      verify(() => repository.approve('topup-1')).called(2);
    });
  });
}
