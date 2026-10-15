import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/wallet/presentation/cubit/wallet_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../wallet_fixtures.dart';

void main() {
  late MockWalletRepository wallets;

  setUp(() => wallets = MockWalletRepository());

  blocTest<WalletCubit, WalletState>(
    'shows the wallet once fetched',
    setUp: () =>
        when(() => wallets.fetch()).thenAnswer((_) async => Ok(testWallet())),
    build: () => WalletCubit(wallets),
    act: (cubit) => cubit.load(),
    expect: () => [
      WalletState(status: WalletStatus.ready, wallet: testWallet()),
    ],
  );

  blocTest<WalletCubit, WalletState>(
    'fails when the first fetch fails',
    setUp: () => when(
      () => wallets.fetch(),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => WalletCubit(wallets),
    act: (cubit) => cubit.load(),
    expect: () => const [WalletState(status: WalletStatus.failed)],
  );

  blocTest<WalletCubit, WalletState>(
    'keeps what is shown when a refresh fails',
    setUp: () => when(
      () => wallets.fetch(),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => WalletCubit(wallets),
    seed: () => WalletState(status: WalletStatus.ready, wallet: testWallet()),
    act: (cubit) => cubit.load(),
    expect: () => <WalletState>[],
  );

  blocTest<WalletCubit, WalletState>(
    'starts over from the spinner on retry',
    setUp: () =>
        when(() => wallets.fetch()).thenAnswer((_) async => Ok(testWallet())),
    build: () => WalletCubit(wallets),
    seed: () => const WalletState(status: WalletStatus.failed),
    act: (cubit) => cubit.retry(),
    expect: () => [
      const WalletState(),
      WalletState(status: WalletStatus.ready, wallet: testWallet()),
    ],
  );
}
