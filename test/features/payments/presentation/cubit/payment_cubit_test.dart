import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/presentation/cubit/payment_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockPaymentRepository payments;
  late MockExternalApps apps;

  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 8000,
  );

  setUpAll(() => registerFallbackValue(Uri()));

  setUp(() {
    payments = MockPaymentRepository();
    apps = MockExternalApps();
    when(() => apps.openLink(any())).thenAnswer((_) async => true);
  });

  void answer(PaymentStatus status) =>
      when(() => payments.fetchOrder('order-1')).thenAnswer(
        (_) async => Ok(PaymentOrder(id: 'order-1', status: status)),
      );

  PaymentCubit build() => PaymentCubit(
    payments: payments,
    apps: apps,
    checkout: checkout,
    pollEvery: const Duration(milliseconds: 10),
  );

  group('open', () {
    blocTest<PaymentCubit, PaymentState>(
      'opens the provider page',
      build: build,
      act: (cubit) => cubit.open(),
      expect: () => [const PaymentState(pageOpened: true)],
      verify: (_) {
        verify(() => apps.openLink(checkout.url)).called(1);
      },
    );

    blocTest<PaymentCubit, PaymentState>(
      'says when the page could not be opened',
      setUp: () => when(() => apps.openLink(any())).thenAnswer(
        (_) async => false,
      ),
      build: build,
      seed: () => const PaymentState(pageOpened: true),
      act: (cubit) => cubit.open(),
      expect: () => [const PaymentState()],
    );
  });

  group('refresh', () {
    for (final (status, progress) in <(PaymentStatus, PaymentProgress)>[
      (PaymentStatus.succeeded, PaymentProgress.paid),
      (PaymentStatus.failed, PaymentProgress.notPaid),
      (PaymentStatus.cancelled, PaymentProgress.notPaid),
      (PaymentStatus.expired, PaymentProgress.notPaid),
      (PaymentStatus.refunded, PaymentProgress.notPaid),
    ]) {
      blocTest<PaymentCubit, PaymentState>(
        'ends as $progress when the server says $status',
        setUp: () => answer(status),
        build: build,
        act: (cubit) => cubit.refresh(),
        expect: () => [PaymentState(progress: progress, status: status)],
      );
    }

    blocTest<PaymentCubit, PaymentState>(
      'keeps waiting while the server says pending',
      setUp: () => answer(PaymentStatus.pending),
      build: build,
      act: (cubit) => cubit.refresh(),
      expect: () => [const PaymentState(status: PaymentStatus.pending)],
    );

    blocTest<PaymentCubit, PaymentState>(
      'keeps waiting when the server can not be reached',
      setUp: () => when(() => payments.fetchOrder('order-1')).thenAnswer(
        (_) async => const Err(NetworkFailure()),
      ),
      build: build,
      act: (cubit) => cubit.refresh(),
      expect: () => <PaymentState>[],
    );

    blocTest<PaymentCubit, PaymentState>(
      'does not ask again once the order ended',
      setUp: () => answer(PaymentStatus.succeeded),
      build: build,
      seed: () => const PaymentState(
        progress: PaymentProgress.paid,
        status: PaymentStatus.succeeded,
      ),
      act: (cubit) => cubit.refresh(),
      expect: () => <PaymentState>[],
      verify: (_) {
        verifyNever(() => payments.fetchOrder(any()));
      },
    );
  });

  group('start', () {
    test('opens the page and asks until the server confirms', () {
      fakeAsync((async) {
        var answers = 0;
        when(() => payments.fetchOrder('order-1')).thenAnswer((_) async {
          answers++;
          return Ok(
            PaymentOrder(
              id: 'order-1',
              status: answers < 3
                  ? PaymentStatus.pending
                  : PaymentStatus.succeeded,
            ),
          );
        });
        final cubit = build();

        unawaited(cubit.start());
        async.elapse(const Duration(milliseconds: 200));

        expect(cubit.state.progress, PaymentProgress.paid);
        expect(cubit.state.pageOpened, isTrue);
        // It stopped asking once the server confirmed.
        expect(answers, 3);
        verify(() => apps.openLink(checkout.url)).called(1);
        unawaited(cubit.close());
      });
    });

    test('a screen that says paid is not proof: only the server is', () {
      fakeAsync((async) {
        answer(PaymentStatus.pending);
        final cubit = build();

        unawaited(cubit.start());
        async.elapse(const Duration(milliseconds: 100));

        expect(cubit.state.progress, PaymentProgress.waiting);
        unawaited(cubit.close());
      });
    });

    test('stops asking when it is closed', () {
      fakeAsync((async) {
        answer(PaymentStatus.pending);
        final cubit = build();
        unawaited(cubit.start());
        async.elapse(const Duration(milliseconds: 35));
        unawaited(cubit.close());
        clearInteractions(payments);

        async.elapse(const Duration(milliseconds: 100));

        verifyNever(() => payments.fetchOrder(any()));
      });
    });

    test('does not ask twice at once when the server is slow', () {
      fakeAsync((async) {
        when(() => payments.fetchOrder('order-1')).thenAnswer(
          (_) => Future<Result<PaymentOrder>>.delayed(
            const Duration(milliseconds: 55),
            () => const Ok(
              PaymentOrder(id: 'order-1', status: PaymentStatus.pending),
            ),
          ),
        );
        final cubit = build();

        unawaited(cubit.start());
        async.elapse(const Duration(milliseconds: 50));

        verify(() => payments.fetchOrder('order-1')).called(1);
        unawaited(cubit.close());
      });
    });
  });
}
