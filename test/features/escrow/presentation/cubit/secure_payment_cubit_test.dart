import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';

import '../../../../helpers/mocks.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  late MockPaymentRepository payments;

  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 35000,
  );

  setUp(() {
    escrow = MockEscrowRepository();
    payments = MockPaymentRepository();
    when(
      () => escrow.fetchInfo('request-1'),
    ).thenAnswer((_) async => Ok(testEscrowInfo(canSecure: true)));
    when(
      () => payments.startEscrowPayment('request-1'),
    ).thenAnswer((_) async => Ok(checkout));
  });

  SecurePaymentCubit build() => SecurePaymentCubit(
    escrow: escrow,
    payments: payments,
    requestId: 'request-1',
  );

  const loaded = SecurePaymentState(
    status: SecurePaymentStatus.editing,
    amountPiastres: 35000,
  );

  group('load', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'shows the amount the server decided',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const SecurePaymentState(), loaded],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'fails when the request can not be paid for',
      setUp: () => when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => Ok(testEscrowInfo())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SecurePaymentState(),
        const SecurePaymentState(status: SecurePaymentStatus.failed),
      ],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'fails when there is no guarantee at all',
      setUp: () => when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SecurePaymentState(),
        const SecurePaymentState(status: SecurePaymentStatus.failed),
      ],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'fails with the failure when the info can not be fetched',
      setUp: () => when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SecurePaymentState(),
        const SecurePaymentState(
          status: SecurePaymentStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('pay', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'starts the payment of the request and holds the checkout',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.pay(),
      expect: () => [
        loaded.copyWith(status: SecurePaymentStatus.starting),
        loaded.copyWith(
          status: SecurePaymentStatus.paying,
          checkout: () => checkout,
        ),
      ],
      verify: (_) {
        verify(() => payments.startEscrowPayment('request-1')).called(1);
      },
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'does nothing before the amount is loaded',
      build: build,
      act: (cubit) => cubit.pay(),
      expect: () => <SecurePaymentState>[],
      verify: (_) {
        verifyNever(() => payments.startEscrowPayment(any()));
      },
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'does not start a second payment while one is starting',
      build: build,
      seed: () => loaded.copyWith(status: SecurePaymentStatus.starting),
      act: (cubit) => cubit.pay(),
      expect: () => <SecurePaymentState>[],
    );

    for (final failure in <Failure>[
      const AlreadySecuredFailure(),
      const EscrowUnavailableFailure(),
      const PaymentsUnavailableFailure(),
      const NetworkFailure(),
    ]) {
      blocTest<SecurePaymentCubit, SecurePaymentState>(
        'goes back to the amount with ${failure.runtimeType}',
        setUp: () => when(
          () => payments.startEscrowPayment('request-1'),
        ).thenAnswer((_) async => Err(failure)),
        build: build,
        seed: () => loaded,
        act: (cubit) => cubit.pay(),
        expect: () => [
          loaded.copyWith(status: SecurePaymentStatus.starting),
          loaded.copyWith(failure: () => failure),
        ],
      );
    }
  });

  group('paymentClosed', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'returns to the amount once the payment screen is closed',
      build: build,
      seed: () => loaded.copyWith(
        status: SecurePaymentStatus.paying,
        checkout: () => checkout,
      ),
      act: (cubit) => cubit.paymentClosed(),
      expect: () => [loaded],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'ignores a close when no payment is open',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.paymentClosed(),
      expect: () => <SecurePaymentState>[],
    );
  });
}
