import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/escrow_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  final held = testEscrowInfo(
    canConfirm: true,
    canDispute: true,
    escrow: testEscrow(EscrowStatus.held),
  );

  setUp(() {
    escrow = MockEscrowRepository();
    when(() => escrow.fetchInfo('request-1')).thenAnswer((_) async => Ok(held));
  });

  EscrowCubit build() => EscrowCubit(escrow: escrow, requestId: 'request-1');

  group('load', () {
    blocTest<EscrowCubit, EscrowState>(
      'shows the payment',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [EscrowState(loaded: true, info: held)],
    );

    blocTest<EscrowCubit, EscrowState>(
      'shows nothing when the request is not hers',
      setUp: () => when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const EscrowState(loaded: true)],
    );

    blocTest<EscrowCubit, EscrowState>(
      'keeps what is shown when a refresh fails',
      setUp: () => when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      seed: () => EscrowState(loaded: true, info: held),
      act: (cubit) => cubit.load(),
      expect: () => <EscrowState>[],
    );
  });

  group('answering', () {
    setUp(() {
      when(
        () => escrow.confirmWork('request-1'),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => escrow.dispute('request-1', any()),
      ).thenAnswer((_) async => const Ok(null));
    });

    blocTest<EscrowCubit, EscrowState>(
      'confirming the work is busy, then fetches the new state',
      build: build,
      seed: () => EscrowState(loaded: true, info: held),
      act: (cubit) => cubit.confirm(),
      expect: () => [
        EscrowState(loaded: true, info: held, busy: true),
        EscrowState(loaded: true, info: held),
      ],
      verify: (_) {
        verify(() => escrow.confirmWork('request-1')).called(1);
        verify(() => escrow.fetchInfo('request-1')).called(1);
      },
    );

    blocTest<EscrowCubit, EscrowState>(
      'a dispute sends the reason',
      build: build,
      seed: () => EscrowState(loaded: true, info: held),
      act: (cubit) => cubit.dispute('الفني ماجاش'),
      verify: (_) {
        verify(() => escrow.dispute('request-1', 'الفني ماجاش')).called(1);
      },
    );

    blocTest<EscrowCubit, EscrowState>(
      'a refused answer says why and fetches the real state',
      setUp: () => when(
        () => escrow.confirmWork('request-1'),
      ).thenAnswer((_) async => const Err(EscrowUnavailableFailure())),
      build: build,
      seed: () => EscrowState(loaded: true, info: held),
      act: (cubit) => cubit.confirm(),
      expect: () => [
        EscrowState(loaded: true, info: held, busy: true),
        EscrowState(
          loaded: true,
          info: held,
          failure: const EscrowUnavailableFailure(),
        ),
      ],
      verify: (_) {
        verify(() => escrow.fetchInfo('request-1')).called(1);
      },
    );

    blocTest<EscrowCubit, EscrowState>(
      'ignores a second tap while one is on its way',
      build: build,
      seed: () => EscrowState(loaded: true, info: held, busy: true),
      act: (cubit) => cubit.confirm(),
      expect: () => <EscrowState>[],
      verify: (_) {
        verifyNever(() => escrow.confirmWork(any()));
      },
    );
  });
}
