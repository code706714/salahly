import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_detail_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_queue_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_review_cubit.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockVerificationRepository repository;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() => repository = MockVerificationRepository());

  group('VerificationQueueCubit', () {
    blocTest<
      VerificationQueueCubit,
      PagedState<VerificationSummary, VerificationStatus>
    >(
      'starts with the waiting submissions and asks for a page of them',
      setUp: () =>
          when(
            () => repository.fetchQueue(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => Ok(
              PagedResult(items: [testVerificationSummary()], total: 1),
            ),
          ),
      build: () => VerificationQueueCubit(repository),
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.filter, VerificationStatus.pending);
        expect(cubit.state.items, [testVerificationSummary()]);
        verify(
          () => repository.fetchQueue(
            VerificationStatus.pending,
            limit: adminPageSize,
            offset: 0,
          ),
        ).called(1);
      },
    );

    blocTest<
      VerificationQueueCubit,
      PagedState<VerificationSummary, VerificationStatus>
    >(
      'asks for the other status when it is chosen',
      setUp: () =>
          when(
            () => repository.fetchQueue(
              any(),
              limit: any(named: 'limit'),
              offset: any(named: 'offset'),
            ),
          ).thenAnswer(
            (_) async => const Ok(PagedResult(items: [], total: 0)),
          ),
      build: () => VerificationQueueCubit(repository),
      act: (cubit) => cubit.filterChanged(VerificationStatus.rejected),
      verify: (_) => verify(
        () => repository.fetchQueue(
          VerificationStatus.rejected,
          limit: adminPageSize,
          offset: 0,
        ),
      ).called(1),
    );
  });

  group('VerificationDetailCubit', () {
    VerificationDetailCubit build() =>
        VerificationDetailCubit(repository, verificationId: 'ver-1');

    blocTest<VerificationDetailCubit, VerificationDetailState>(
      'loads the submission',
      setUp: () => when(
        () => repository.fetchDetail('ver-1'),
      ).thenAnswer((_) async => Ok(testVerificationDetail())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const VerificationDetailState(),
        VerificationDetailState(
          detail: testVerificationDetail(),
          isLoading: false,
        ),
      ],
      verify: (_) => verify(() => repository.fetchDetail('ver-1')).called(1),
    );

    blocTest<VerificationDetailCubit, VerificationDetailState>(
      'says why it could not load',
      setUp: () => when(
        () => repository.fetchDetail(any()),
      ).thenAnswer((_) async => const Err(AdminNotFoundFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => const [
        VerificationDetailState(),
        VerificationDetailState(
          isLoading: false,
          failure: AdminNotFoundFailure(),
        ),
      ],
    );
  });

  group('VerificationReviewCubit', () {
    VerificationReviewCubit build() =>
        VerificationReviewCubit(repository, verificationId: 'ver-1');

    blocTest<VerificationReviewCubit, ActionState>(
      'approves the submission',
      setUp: () => when(
        () => repository.approve('ver-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.approve(),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(
          completed: 1,
          outcome: AdminOutcome.verificationApproved,
        ),
      ],
    );

    blocTest<VerificationReviewCubit, ActionState>(
      'rejects it with the reason the technician will read',
      setUp: () => when(
        () => repository.reject('ver-1', 'الصورة مش واضحة'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.reject('الصورة مش واضحة'),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(
          completed: 1,
          outcome: AdminOutcome.verificationRejected,
        ),
      ],
    );

    blocTest<VerificationReviewCubit, ActionState>(
      'says when someone reviewed it first',
      setUp: () => when(
        () => repository.approve(any()),
      ).thenAnswer((_) async => const Err(NotPendingFailure())),
      build: build,
      act: (cubit) => cubit.approve(),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(failure: NotPendingFailure()),
      ],
    );

    test('sends no second approval while the first is on its way', () async {
      when(() => repository.approve(any())).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return const Ok(null);
      });
      final cubit = build();
      addTearDown(cubit.close);

      await Future.wait([cubit.approve(), cubit.approve()]);

      verify(() => repository.approve('ver-1')).called(1);
    });
  });
}
