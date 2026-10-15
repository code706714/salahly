import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/technician_escrow_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  final held = testTechnicianEscrow(EscrowStatus.held, canConfirm: true);
  final confirmed = testTechnicianEscrow(
    EscrowStatus.held,
    technicianConfirmed: true,
  );

  setUp(() => escrow = MockEscrowRepository());

  TechnicianEscrowCubit build() =>
      TechnicianEscrowCubit(escrow: escrow, requestId: 'request-1');

  void fetches(List<TechnicianEscrow?> answers) {
    final queue = [...answers];
    when(
      () => escrow.fetchTechnicianEscrow('request-1'),
    ).thenAnswer((_) async => Ok(queue.removeAt(0)));
  }

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'shows the payment the consumer secured',
    setUp: () => fetches([held]),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [TechnicianEscrowState(escrow: held)],
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'keeps what is shown when a refresh fails',
    setUp: () => when(
      () => escrow.fetchTechnicianEscrow('request-1'),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    seed: () => TechnicianEscrowState(escrow: held),
    act: (cubit) => cubit.load(),
    expect: () => <TechnicianEscrowState>[],
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'confirms the work and reads the payment again',
    setUp: () {
      when(
        () => escrow.technicianConfirmWork('request-1'),
      ).thenAnswer((_) async => const Ok(null));
      fetches([confirmed]);
    },
    build: build,
    seed: () => TechnicianEscrowState(escrow: held),
    act: (cubit) => cubit.confirm(),
    expect: () => [
      TechnicianEscrowState(escrow: held, busy: true),
      TechnicianEscrowState(escrow: held),
      TechnicianEscrowState(escrow: confirmed),
    ],
    verify: (_) =>
        verify(() => escrow.technicianConfirmWork('request-1')).called(1),
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'sends his objection with the reason',
    setUp: () {
      when(
        () => escrow.technicianDispute('request-1', 'العميل رفض'),
      ).thenAnswer((_) async => const Ok(null));
      fetches([held]);
    },
    build: build,
    seed: () => TechnicianEscrowState(escrow: held),
    act: (cubit) => cubit.dispute('العميل رفض'),
    verify: (_) => verify(
      () => escrow.technicianDispute('request-1', 'العميل رفض'),
    ).called(1),
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'reports why an answer was refused',
    setUp: () {
      when(
        () => escrow.technicianConfirmWork('request-1'),
      ).thenAnswer((_) async => const Err(EscrowUnavailableFailure()));
      fetches([held]);
    },
    build: build,
    seed: () => TechnicianEscrowState(escrow: held),
    act: (cubit) => cubit.confirm(),
    expect: () => [
      TechnicianEscrowState(escrow: held, busy: true),
      TechnicianEscrowState(
        escrow: held,
        failure: const EscrowUnavailableFailure(),
      ),
    ],
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrowState>(
    'ignores a second answer while one is on its way',
    build: build,
    seed: () => TechnicianEscrowState(escrow: held, busy: true),
    act: (cubit) => cubit.confirm(),
    expect: () => <TechnicianEscrowState>[],
    verify: (_) => verifyNever(() => escrow.technicianConfirmWork(any())),
  );
}
