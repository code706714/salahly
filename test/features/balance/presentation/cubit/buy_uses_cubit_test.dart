import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockBalanceRepository balance;
  late MockPaymentRepository payments;

  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 8000,
  );

  setUpAll(() => registerFallbackValue(UserRole.consumer));

  setUp(() {
    balance = MockBalanceRepository();
    payments = MockPaymentRepository();
    stubBalance(balance);
    when(
      () => payments.startCreditPackPayment(
        packId: any(named: 'packId'),
        expectedPricePiastres: any(named: 'expectedPricePiastres'),
      ),
    ).thenAnswer((_) async => Ok(checkout));
  });

  BuyUsesCubit build({UserRole role = UserRole.consumer}) =>
      BuyUsesCubit(balance: balance, payments: payments, role: role);

  const loaded = BuyUsesState(
    status: BuyUsesStatus.editing,
    packs: consumerPacks,
    packId: 'pack-5',
  );

  const repriced = [
    CreditPack(id: 'pack-1', uses: 1, pricePiastres: 2000),
    CreditPack(id: 'pack-5', uses: 5, pricePiastres: 9000),
  ];

  group('load', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'fetches the role packs and picks the cheapest per use',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const BuyUsesState(), loaded],
      verify: (_) {
        verify(() => balance.fetchPacks(UserRole.consumer)).called(1);
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'asks for the technician packs of a technician',
      setUp: () => stubBalance(balance, consumer: false),
      build: () => build(role: UserRole.technician),
      act: (cubit) => cubit.load(),
      expect: () => [
        const BuyUsesState(),
        loaded.copyWith(packs: technicianPacks, packId: 'pack-t10'),
      ],
      verify: (_) {
        verify(() => balance.fetchPacks(UserRole.technician)).called(1);
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'fails with the failure when the packs cannot be fetched',
      setUp: () => when(
        () => balance.fetchPacks(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BuyUsesState(),
        const BuyUsesState(
          status: BuyUsesStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'fails when no pack is on sale',
      setUp: () => when(
        () => balance.fetchPacks(any()),
      ).thenAnswer((_) async => const Ok([])),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BuyUsesState(),
        const BuyUsesState(status: BuyUsesStatus.failed),
      ],
    );
  });

  group('pickPack', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'picks another pack',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.pickPack('pack-1'),
      expect: () => [loaded.copyWith(packId: 'pack-1')],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'ignores a pick while a payment is starting',
      build: build,
      seed: () => loaded.copyWith(status: BuyUsesStatus.starting),
      act: (cubit) => cubit.pickPack('pack-1'),
      expect: () => <BuyUsesState>[],
    );
  });

  group('pay', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'starts the payment of the picked pack at the price shown',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.pay(),
      expect: () => [
        loaded.copyWith(status: BuyUsesStatus.starting),
        loaded.copyWith(
          status: BuyUsesStatus.paying,
          checkout: () => checkout,
        ),
      ],
      verify: (_) {
        verify(
          () => payments.startCreditPackPayment(
            packId: 'pack-5',
            expectedPricePiastres: 8000,
          ),
        ).called(1);
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'does nothing before the packs are loaded',
      build: build,
      act: (cubit) => cubit.pay(),
      expect: () => <BuyUsesState>[],
      verify: (_) {
        verifyNever(
          () => payments.startCreditPackPayment(
            packId: any(named: 'packId'),
            expectedPricePiastres: any(named: 'expectedPricePiastres'),
          ),
        );
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'does not start a second payment while one is starting',
      build: build,
      seed: () => loaded.copyWith(status: BuyUsesStatus.starting),
      act: (cubit) => cubit.pay(),
      expect: () => <BuyUsesState>[],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'goes back to the packs with the failure when the server refuses',
      setUp: () => when(
        () => payments.startCreditPackPayment(
          packId: any(named: 'packId'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer((_) async => const Err(PaymentsUnavailableFailure())),
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.pay(),
      expect: () => [
        loaded.copyWith(status: BuyUsesStatus.starting),
        loaded.copyWith(failure: () => const PaymentsUnavailableFailure()),
      ],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'shows the new prices when the pack price changed',
      setUp: () {
        when(
          () => payments.startCreditPackPayment(
            packId: any(named: 'packId'),
            expectedPricePiastres: any(named: 'expectedPricePiastres'),
          ),
        ).thenAnswer((_) async => const Err(PriceChangedFailure()));
        when(() => balance.fetchPacks(any())).thenAnswer(
          (_) async => const Ok(repriced),
        );
      },
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.pay(),
      expect: () => [
        loaded.copyWith(status: BuyUsesStatus.starting),
        loaded.copyWith(failure: () => const PriceChangedFailure()),
        loaded.copyWith(
          packs: repriced,
          failure: () => const PriceChangedFailure(),
        ),
      ],
      verify: (_) {
        verify(() => balance.fetchPacks(UserRole.consumer)).called(1);
      },
    );
  });

  group('paymentClosed', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'returns to the packs once the payment screen is closed',
      build: build,
      seed: () => loaded.copyWith(
        status: BuyUsesStatus.paying,
        checkout: () => checkout,
      ),
      act: (cubit) => cubit.paymentClosed(),
      expect: () => [loaded],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'ignores a close when no payment is open',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.paymentClosed(),
      expect: () => <BuyUsesState>[],
    );
  });
}
