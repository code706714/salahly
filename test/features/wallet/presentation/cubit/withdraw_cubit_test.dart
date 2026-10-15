import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/failures/wallet_failures.dart';
import 'package:salahly/features/wallet/presentation/cubit/withdraw_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../wallet_fixtures.dart';

void main() {
  late MockWalletRepository wallets;

  setUpAll(() => registerFallbackValue(TopupMethod.wallet));

  setUp(() {
    wallets = MockWalletRepository();
    when(
      () => wallets.fetch(),
    ).thenAnswer((_) async => Ok(testWallet(last: testDestination)));
    when(
      () => wallets.requestWithdrawal(
        amountPiastres: any(named: 'amountPiastres'),
        method: any(named: 'method'),
        account: any(named: 'account'),
        holderName: any(named: 'holderName'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  const filled = WithdrawState(
    status: WithdrawStatus.editing,
    balancePiastres: 85000,
    minPiastres: 5000,
    account: '01005551234',
    holder: 'محمود سعيد',
  );

  WithdrawCubit ready() => WithdrawCubit(wallets);

  group('load', () {
    blocTest<WithdrawCubit, WithdrawState>(
      'fills the form with the last number used',
      build: ready,
      act: (cubit) => cubit.load(),
      expect: () => [const WithdrawState(), filled],
    );

    blocTest<WithdrawCubit, WithdrawState>(
      'starts empty on a wallet number before any withdrawal',
      setUp: () => when(
        () => wallets.fetch(),
      ).thenAnswer((_) async => Ok(testWallet())),
      build: ready,
      act: (cubit) => cubit.load(),
      expect: () => [
        const WithdrawState(),
        const WithdrawState(
          status: WithdrawStatus.editing,
          balancePiastres: 85000,
          minPiastres: 5000,
        ),
      ],
    );

    blocTest<WithdrawCubit, WithdrawState>(
      'fails when the wallet can not be read',
      setUp: () => when(
        () => wallets.fetch(),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: ready,
      act: (cubit) => cubit.load(),
      expect: () => [
        const WithdrawState(),
        const WithdrawState(
          status: WithdrawStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('what can be sent', () {
    test('needs an amount between the minimum and the balance', () {
      expect(filled.copyWith(amount: '49').canSend, isFalse);
      expect(filled.copyWith(amount: '50').canSend, isTrue);
      expect(filled.copyWith(amount: '850').canSend, isTrue);
      expect(filled.copyWith(amount: '851').canSend, isFalse);
      expect(filled.copyWith(amount: '').canSend, isFalse);
    });

    test('needs a valid number for the method', () {
      expect(filled.copyWith(amount: '100', account: '123').canSend, isFalse);
    });

    test('needs a name on the account', () {
      expect(filled.copyWith(amount: '100', holder: ' ').canSend, isFalse);
    });
  });

  group('send', () {
    blocTest<WithdrawCubit, WithdrawState>(
      'asks for the amount in piastres',
      build: ready,
      seed: () => filled.copyWith(amount: '200'),
      act: (cubit) => cubit.send(),
      expect: () => [
        filled.copyWith(amount: '200', status: WithdrawStatus.sending),
        filled.copyWith(amount: '200', status: WithdrawStatus.sent),
      ],
      verify: (_) => verify(
        () => wallets.requestWithdrawal(
          amountPiastres: 20000,
          method: TopupMethod.wallet,
          account: '01005551234',
          holderName: 'محمود سعيد',
        ),
      ).called(1),
    );

    blocTest<WithdrawCubit, WithdrawState>(
      'sends nothing while the form is not valid',
      build: ready,
      seed: () => filled.copyWith(amount: '1'),
      act: (cubit) => cubit.send(),
      expect: () => <WithdrawState>[],
      verify: (_) => verifyNever(
        () => wallets.requestWithdrawal(
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
          account: any(named: 'account'),
          holderName: any(named: 'holderName'),
        ),
      ),
    );

    blocTest<WithdrawCubit, WithdrawState>(
      'goes back to editing with the reason it was refused',
      setUp: () => when(
        () => wallets.requestWithdrawal(
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
          account: any(named: 'account'),
          holderName: any(named: 'holderName'),
        ),
      ).thenAnswer((_) async => const Err(InsufficientBalanceFailure())),
      build: ready,
      seed: () => filled.copyWith(amount: '200'),
      act: (cubit) => cubit.send(),
      expect: () => [
        filled.copyWith(amount: '200', status: WithdrawStatus.sending),
        filled.copyWith(
          amount: '200',
          failure: () => const InsufficientBalanceFailure(),
        ),
      ],
    );
  });

  group('editing', () {
    blocTest<WithdrawCubit, WithdrawState>(
      'clears an old failure on any change',
      build: ready,
      seed: () => filled.copyWith(failure: () => const NetworkFailure()),
      act: (cubit) => cubit
        ..setAmount('100')
        ..pickMethod(TopupMethod.instapay)
        ..setAccount('a@instapay')
        ..setHolder('أحمد'),
      expect: () => [
        filled.copyWith(amount: '100'),
        filled.copyWith(amount: '100', method: TopupMethod.instapay),
        filled.copyWith(
          amount: '100',
          method: TopupMethod.instapay,
          account: 'a@instapay',
        ),
        filled.copyWith(
          amount: '100',
          method: TopupMethod.instapay,
          account: 'a@instapay',
          holder: 'أحمد',
        ),
      ],
    );
  });
}
