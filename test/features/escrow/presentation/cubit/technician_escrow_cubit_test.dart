import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/presentation/cubit/technician_escrow_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockEscrowRepository escrow;
  const held = TechnicianEscrow(
    status: EscrowStatus.held,
    amountPiastres: 35000,
  );

  setUp(() => escrow = MockEscrowRepository());

  TechnicianEscrowCubit build() =>
      TechnicianEscrowCubit(escrow: escrow, requestId: 'request-1');

  blocTest<TechnicianEscrowCubit, TechnicianEscrow?>(
    'shows the payment the consumer secured',
    setUp: () => when(
      () => escrow.fetchTechnicianEscrow('request-1'),
    ).thenAnswer((_) async => const Ok(held)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [held],
  );

  blocTest<TechnicianEscrowCubit, TechnicianEscrow?>(
    'keeps what is shown when a refresh fails',
    setUp: () => when(
      () => escrow.fetchTechnicianEscrow('request-1'),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    seed: () => held,
    act: (cubit) => cubit.load(),
    expect: () => <TechnicianEscrow?>[],
  );
}
