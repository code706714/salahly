import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/presentation/cubit/balance_cubit.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockBalanceRepository balance;
  late MockSessionCubit session;
  final topups = [testTopup(), testTopup(id: 'topup-2')];
  final ledger = [
    testLedgerEntry(id: 2, delta: 5, reason: LedgerReason.topup),
    testLedgerEntry(),
  ];

  setUpAll(() => registerFallbackValue(UserRole.consumer));

  setUp(() {
    balance = MockBalanceRepository();
    session = MockSessionCubit();
    when(session.refreshProfile).thenAnswer((_) async {});
    when(
      () => balance.fetchTopups(any()),
    ).thenAnswer((_) async => Ok(topups));
    when(
      () => balance.fetchLedger(any()),
    ).thenAnswer((_) async => Ok(ledger));
  });

  BalanceCubit build({UserRole role = UserRole.consumer}) =>
      BalanceCubit(balance: balance, session: session, role: role);

  blocTest<BalanceCubit, BalanceState>(
    'loads the transfers and the movements of the role',
    build: () => build(role: UserRole.technician),
    act: (cubit) => cubit.load(),
    expect: () => [
      BalanceState(
        status: BalanceStatus.ready,
        topups: topups,
        ledger: ledger,
      ),
    ],
    verify: (_) {
      verify(() => balance.fetchTopups(UserRole.technician)).called(1);
      verify(() => balance.fetchLedger(UserRole.technician)).called(1);
    },
  );

  blocTest<BalanceCubit, BalanceState>(
    'fetches the profile too, so the uses left are right',
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    verify: (_) => verify(session.refreshProfile).called(2),
  );

  blocTest<BalanceCubit, BalanceState>(
    'shows the loading state again when retrying after a failure',
    setUp: () => when(
      () => balance.fetchTopups(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    seed: () => const BalanceState(
      status: BalanceStatus.failed,
      failure: NetworkFailure(),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      const BalanceState(),
      const BalanceState(
        status: BalanceStatus.failed,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<BalanceCubit, BalanceState>(
    'fails when nothing was loaded before',
    setUp: () => when(
      () => balance.fetchTopups(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const BalanceState(
        status: BalanceStatus.failed,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<BalanceCubit, BalanceState>(
    'fails when only the movements cannot be loaded',
    setUp: () => when(
      () => balance.fetchLedger(any()),
    ).thenAnswer((_) async => const Err(UnexpectedFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [
      const BalanceState(
        status: BalanceStatus.failed,
        failure: UnexpectedFailure(),
      ),
    ],
  );

  blocTest<BalanceCubit, BalanceState>(
    'keeps what is shown when a refresh fails',
    build: build,
    act: (cubit) async {
      await cubit.load();
      when(
        () => balance.fetchLedger(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await cubit.load();
    },
    expect: () => [
      BalanceState(
        status: BalanceStatus.ready,
        topups: topups,
        ledger: ledger,
      ),
      BalanceState(
        status: BalanceStatus.ready,
        topups: topups,
        ledger: ledger,
        failure: const NetworkFailure(),
      ),
    ],
  );

  blocTest<BalanceCubit, BalanceState>(
    'a refresh that works clears the failure',
    build: build,
    seed: () => BalanceState(
      status: BalanceStatus.ready,
      topups: topups,
      failure: const NetworkFailure(),
    ),
    act: (cubit) => cubit.load(),
    expect: () => [
      BalanceState(
        status: BalanceStatus.ready,
        topups: topups,
        ledger: ledger,
      ),
    ],
  );

  test('does not emit once closed', () async {
    final cubit = build();
    final loading = cubit.load();
    await cubit.close();
    await loading;
    expect(cubit.state, const BalanceState());
  });
}
