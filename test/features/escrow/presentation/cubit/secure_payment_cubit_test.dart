import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  late MockBalanceRepository balance;
  late MockPhotoPicker photos;

  setUpAll(() => registerFallbackValue(TopupMethod.instapay));

  setUp(() {
    escrow = MockEscrowRepository();
    balance = MockBalanceRepository();
    photos = MockPhotoPicker();
    when(() => photos.discard(any())).thenAnswer((_) async {});
    when(
      () => escrow.fetchInfo('request-1'),
    ).thenAnswer((_) async => Ok(testEscrowInfo(canSecure: true)));
    when(
      () => balance.uploadScreenshot(any()),
    ).thenAnswer((_) async => const Ok('consumer-1/proof.jpg'));
    when(
      () => escrow.secure(
        requestId: any(named: 'requestId'),
        method: any(named: 'method'),
        senderAccount: any(named: 'senderAccount'),
        screenshotPath: any(named: 'screenshotPath'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  SecurePaymentCubit build() => SecurePaymentCubit(
    escrow: escrow,
    balance: balance,
    photos: photos,
    requestId: 'request-1',
  );

  const loaded = SecurePaymentState(
    status: SecurePaymentStatus.editing,
    amountPiastres: 35000,
    accounts: paymentAccounts,
    method: TopupMethod.instapay,
  );

  SecurePaymentState ready() => loaded.copyWith(
    sender: '0111 456 7720',
    screenshot: () => '/tmp/proof.jpg',
  );

  Future<void> Function(SecurePaymentCubit) fillAndSubmit() => (cubit) async {
    await cubit.load();
    cubit
      ..setSender('0111 456 7720')
      ..attachScreenshot('/tmp/proof.jpg');
    await cubit.submit();
  };

  group('load', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'shows the amount and the first method on offer',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const SecurePaymentState(), loaded],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'fails without a reason when the payment can not be made now',
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

  group('editing', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'picks a method and types the sender',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit
        ..pickMethod(TopupMethod.wallet)
        ..setSender('0111'),
      expect: () => [
        loaded.copyWith(method: TopupMethod.wallet),
        loaded.copyWith(method: TopupMethod.wallet, sender: '0111'),
      ],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'deletes the screenshot it replaces',
      build: build,
      seed: () => loaded.copyWith(screenshot: () => '/tmp/one.jpg'),
      act: (cubit) => cubit.attachScreenshot('/tmp/two.jpg'),
      verify: (_) {
        verify(() => photos.discard('/tmp/one.jpg')).called(1);
      },
    );

    test('can be sent with a valid sender and a screenshot only', () {
      expect(loaded.canSubmit, isFalse);
      expect(loaded.copyWith(sender: '0111 456 7720').canSubmit, isFalse);
      expect(ready().canSubmit, isTrue);
      expect(ready().copyWith(sender: '01').canSubmit, isFalse);
    });
  });

  group('submit', () {
    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'uploads the screenshot, then says the transfer was made',
      build: build,
      act: fillAndSubmit(),
      skip: 4,
      expect: () => [
        ready().copyWith(status: SecurePaymentStatus.submitting),
        ready().copyWith(status: SecurePaymentStatus.submitted),
      ],
      verify: (_) {
        verify(() => balance.uploadScreenshot('/tmp/proof.jpg')).called(1);
        verify(
          () => escrow.secure(
            requestId: 'request-1',
            method: TopupMethod.instapay,
            senderAccount: '01114567720',
            screenshotPath: 'consumer-1/proof.jpg',
          ),
        ).called(1);
        verify(() => photos.discard('/tmp/proof.jpg')).called(1);
      },
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'sends nothing until the form is complete',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.submit(),
      expect: () => <SecurePaymentState>[],
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'goes back to editing when the upload fails',
      setUp: () => when(
        () => balance.uploadScreenshot(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: fillAndSubmit(),
      skip: 4,
      expect: () => [
        ready().copyWith(status: SecurePaymentStatus.submitting),
        ready().copyWith(failure: () => const NetworkFailure()),
      ],
      verify: (_) {
        verifyNever(
          () => escrow.secure(
            requestId: any(named: 'requestId'),
            method: any(named: 'method'),
            senderAccount: any(named: 'senderAccount'),
            screenshotPath: any(named: 'screenshotPath'),
          ),
        );
      },
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'a refusal keeps the form, and a retry does not upload again',
      setUp: () => when(
        () => escrow.secure(
          requestId: any(named: 'requestId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
        ),
      ).thenAnswer((_) async => const Err(AlreadySecuredFailure())),
      build: build,
      act: (cubit) async {
        await fillAndSubmit()(cubit);
        await cubit.submit();
      },
      verify: (cubit) {
        expect(cubit.state.failure, const AlreadySecuredFailure());
        expect(cubit.state.status, SecurePaymentStatus.editing);
        verify(() => balance.uploadScreenshot(any())).called(1);
      },
    );

    blocTest<SecurePaymentCubit, SecurePaymentState>(
      'uploads again after the server did not know the upload',
      setUp: () => when(
        () => escrow.secure(
          requestId: any(named: 'requestId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
        ),
      ).thenAnswer((_) async => const Err(InvalidScreenshotFailure())),
      build: build,
      act: (cubit) async {
        await fillAndSubmit()(cubit);
        await cubit.submit();
      },
      verify: (_) {
        verify(() => balance.uploadScreenshot(any())).called(2);
      },
    );

    test('deletes the screenshot when the screen closes unsent', () async {
      final cubit = build();
      await cubit.load();
      cubit.attachScreenshot('/tmp/proof.jpg');

      await cubit.close();

      verify(() => photos.discard('/tmp/proof.jpg')).called(1);
    });
  });
}
