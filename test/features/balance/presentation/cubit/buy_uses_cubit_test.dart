import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockBalanceRepository balance;
  late MockPhotoPicker photos;

  setUpAll(() {
    registerFallbackValue(UserRole.consumer);
    registerFallbackValue(TopupMethod.instapay);
  });

  setUp(() {
    balance = MockBalanceRepository();
    photos = MockPhotoPicker();
    when(() => photos.discard(any())).thenAnswer((_) async {});
    stubBalance(balance);
    when(
      () => balance.uploadScreenshot(any()),
    ).thenAnswer((_) async => const Ok('consumer-1/proof.jpg'));
    when(
      () => balance.submitTopup(
        packId: any(named: 'packId'),
        method: any(named: 'method'),
        senderAccount: any(named: 'senderAccount'),
        screenshotPath: any(named: 'screenshotPath'),
        expectedPricePiastres: any(named: 'expectedPricePiastres'),
      ),
    ).thenAnswer((_) async => const Ok('topup-1'));
  });

  BuyUsesCubit build({UserRole role = UserRole.consumer}) =>
      BuyUsesCubit(balance: balance, photos: photos, role: role);

  const loaded = BuyUsesState(
    status: BuyUsesStatus.editing,
    packs: consumerPacks,
    accounts: paymentAccounts,
    packId: 'pack-5',
    method: TopupMethod.instapay,
  );

  BuyUsesState ready() => loaded.copyWith(
    sender: '0111 456 7720',
    screenshot: () => '/tmp/proof.jpg',
  );

  Future<void> Function(BuyUsesCubit) fillAndSubmit() => (cubit) async {
    await cubit.load();
    cubit
      ..setSender('0111 456 7720')
      ..attachScreenshot('/tmp/proof.jpg');
    await cubit.submit();
  };

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
      'starts with the only method on offer',
      setUp: () => when(
        balance.fetchPaymentAccounts,
      ).thenAnswer((_) async => Ok([paymentAccounts.last])),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BuyUsesState(),
        loaded.copyWith(
          accounts: [paymentAccounts.last],
          method: TopupMethod.wallet,
        ),
      ],
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
      'fails with the failure when the accounts cannot be fetched',
      setUp: () => when(
        balance.fetchPaymentAccounts,
      ).thenAnswer((_) async => const Err(UnexpectedFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const BuyUsesState(),
        const BuyUsesState(
          status: BuyUsesStatus.failed,
          failure: UnexpectedFailure(),
        ),
      ],
    );

    for (final (name, stub) in [
      (
        'no packs',
        () => when(
          () => balance.fetchPacks(any()),
        ).thenAnswer((_) async => const Ok(<CreditPack>[])),
      ),
      (
        'no accounts',
        () => when(
          balance.fetchPaymentAccounts,
        ).thenAnswer((_) async => const Ok(<PaymentAccount>[])),
      ),
    ]) {
      blocTest<BuyUsesCubit, BuyUsesState>(
        'fails without a reason when there are $name',
        setUp: stub,
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => [
          const BuyUsesState(),
          const BuyUsesState(status: BuyUsesStatus.failed),
        ],
      );
    }
  });

  group('editing', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'picks a pack, a method and types the sender',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit
        ..pickPack('pack-1')
        ..pickMethod(TopupMethod.wallet)
        ..setSender('0111'),
      expect: () => [
        loaded.copyWith(packId: 'pack-1'),
        loaded.copyWith(packId: 'pack-1', method: TopupMethod.wallet),
        loaded.copyWith(
          packId: 'pack-1',
          method: TopupMethod.wallet,
          sender: '0111',
        ),
      ],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'ignores a pack or method picked while sending',
      build: build,
      seed: () => loaded.copyWith(status: BuyUsesStatus.submitting),
      act: (cubit) => cubit
        ..pickPack('pack-1')
        ..pickMethod(TopupMethod.wallet),
      expect: () => const <BuyUsesState>[],
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'attaches a screenshot and picks another',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit
        ..attachScreenshot('/tmp/a.jpg')
        ..attachScreenshot('/tmp/b.jpg'),
      expect: () => [
        loaded.copyWith(screenshot: () => '/tmp/a.jpg'),
        loaded.copyWith(screenshot: () => '/tmp/b.jpg'),
      ],
    );

    test('can be sent once the sender and the screenshot are valid', () {
      expect(loaded.canSubmit, isFalse);
      expect(loaded.copyWith(sender: '0111').canSubmit, isFalse);
      expect(ready().canSubmit, isTrue);
      expect(
        ready()
            .copyWith(method: TopupMethod.wallet, sender: 'a@instapay')
            .canSubmit,
        isFalse,
      );
      expect(
        ready().copyWith(status: BuyUsesStatus.submitting).canSubmit,
        isFalse,
      );
    });

    test('knows what the pack saves against a single use', () {
      expect(loaded.singlePricePiastres, 2000);
      expect(loaded.pack, consumerPacks.last);
      expect(loaded.account, paymentAccounts.first);
    });
  });

  group('submit', () {
    blocTest<BuyUsesCubit, BuyUsesState>(
      'uploads the screenshot, then sends only what the server needs',
      build: build,
      act: fillAndSubmit(),
      skip: 4,
      expect: () => [
        ready().copyWith(status: BuyUsesStatus.submitting),
        ready().copyWith(status: BuyUsesStatus.submitted),
      ],
      verify: (_) {
        verifyInOrder([
          () => balance.uploadScreenshot('/tmp/proof.jpg'),
          () => balance.submitTopup(
            packId: 'pack-5',
            method: TopupMethod.instapay,
            senderAccount: '01114567720',
            screenshotPath: 'consumer-1/proof.jpg',
            expectedPricePiastres: 8000,
          ),
        ]);
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'sends nothing while the form is not valid',
      build: build,
      seed: () => loaded,
      act: (cubit) => cubit.submit(),
      expect: () => const <BuyUsesState>[],
      verify: (_) {
        verifyNever(() => balance.uploadScreenshot(any()));
      },
    );

    blocTest<BuyUsesCubit, BuyUsesState>(
      'goes back to editing with the failure when the upload fails',
      setUp: () => when(
        () => balance.uploadScreenshot(any()),
      ).thenAnswer((_) async => const Err(UploadLimitFailure())),
      build: build,
      act: fillAndSubmit(),
      skip: 5,
      expect: () => [
        ready().copyWith(failure: () => const UploadLimitFailure()),
      ],
      verify: (_) {
        verifyNever(
          () => balance.submitTopup(
            packId: any(named: 'packId'),
            method: any(named: 'method'),
            senderAccount: any(named: 'senderAccount'),
            screenshotPath: any(named: 'screenshotPath'),
            expectedPricePiastres: any(named: 'expectedPricePiastres'),
          ),
        );
      },
    );

    for (final failure in <Failure>[
      const TooManyPendingFailure(),
      const PackNotFoundFailure(),
      const MethodUnavailableFailure(),
      const InvalidSenderFailure(),
      const NetworkFailure(),
      const PriceChangedFailure(),
    ]) {
      blocTest<BuyUsesCubit, BuyUsesState>(
        'goes back to editing after $failure',
        setUp: () => when(
          () => balance.submitTopup(
            packId: any(named: 'packId'),
            method: any(named: 'method'),
            senderAccount: any(named: 'senderAccount'),
            screenshotPath: any(named: 'screenshotPath'),
            expectedPricePiastres: any(named: 'expectedPricePiastres'),
          ),
        ).thenAnswer((_) async => Err(failure)),
        build: build,
        act: fillAndSubmit(),
        skip: 5,
        expect: () => [ready().copyWith(failure: () => failure)],
      );
    }

    test(
      'shows the new prices and keeps the form after a price change',
      () async {
        const changed = [
          CreditPack(id: 'pack-1', uses: 1, pricePiastres: 2500),
          CreditPack(id: 'pack-5', uses: 5, pricePiastres: 9000),
        ];
        when(
          () => balance.submitTopup(
            packId: any(named: 'packId'),
            method: any(named: 'method'),
            senderAccount: any(named: 'senderAccount'),
            screenshotPath: any(named: 'screenshotPath'),
            expectedPricePiastres: any(named: 'expectedPricePiastres'),
          ),
        ).thenAnswer((_) async => const Err(PriceChangedFailure()));
        final cubit = build();
        await fillAndSubmit()(cubit);
        when(
          () => balance.fetchPacks(any()),
        ).thenAnswer((_) async => const Ok(changed));
        await cubit.submit();

        verify(() => balance.fetchPacks(UserRole.consumer)).called(3);
        expect(cubit.state.packs, changed);
        expect(cubit.state.pack?.pricePiastres, 9000);
        expect(cubit.state.status, BuyUsesStatus.editing);
        expect(cubit.state.failure, const PriceChangedFailure());
        expect(cubit.state.screenshot, '/tmp/proof.jpg');
        expect(cubit.state.sender, '0111 456 7720');
        await cubit.close();
      },
    );

    test('does not send once closed during the upload', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..setSender('0111 456 7720')
        ..attachScreenshot('/tmp/proof.jpg');
      final sending = cubit.submit();
      await cubit.close();
      await sending;

      verifyNever(
        () => balance.submitTopup(
          packId: any(named: 'packId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      );
    });

    test('does not upload the same screenshot twice on a retry', () async {
      var attempts = 0;
      when(
        () => balance.submitTopup(
          packId: any(named: 'packId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer(
        (_) async =>
            ++attempts == 1 ? const Err(NetworkFailure()) : const Ok('t'),
      );
      final cubit = build();
      await fillAndSubmit()(cubit);
      await cubit.submit();

      verify(() => balance.uploadScreenshot(any())).called(1);
      expect(cubit.state.status, BuyUsesStatus.submitted);
      await cubit.close();
    });

    test('uploads again when the server did not accept the upload', () async {
      var attempts = 0;
      when(
        () => balance.submitTopup(
          packId: any(named: 'packId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer(
        (_) async => ++attempts == 1
            ? const Err(InvalidScreenshotFailure())
            : const Ok('t'),
      );
      final cubit = build();
      await fillAndSubmit()(cubit);
      await cubit.submit();

      verify(() => balance.uploadScreenshot(any())).called(2);
      await cubit.close();
    });

    test('uploads a new screenshot picked after a failure', () async {
      when(
        () => balance.submitTopup(
          packId: any(named: 'packId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = build();
      await fillAndSubmit()(cubit);
      cubit.attachScreenshot('/tmp/other.jpg');
      await cubit.submit();

      verify(() => balance.uploadScreenshot('/tmp/other.jpg')).called(1);
      await cubit.close();
    });
  });

  group('the screenshot file', () {
    test('is deleted once the transfer is sent', () async {
      final cubit = build();
      await fillAndSubmit()(cubit);
      await cubit.close();

      verify(() => photos.discard('/tmp/proof.jpg')).called(1);
    });

    test('is deleted when another one replaces it', () async {
      final cubit = build();
      await cubit.load();
      cubit
        ..attachScreenshot('/tmp/a.jpg')
        ..attachScreenshot('/tmp/a.jpg')
        ..attachScreenshot('/tmp/b.jpg');

      verify(() => photos.discard('/tmp/a.jpg')).called(1);
      verifyNever(() => photos.discard('/tmp/b.jpg'));
      await cubit.close();
    });

    test('is deleted when the cubit closes without sending', () async {
      final cubit = build();
      await cubit.load();
      cubit.attachScreenshot('/tmp/proof.jpg');
      await cubit.close();

      verify(() => photos.discard('/tmp/proof.jpg')).called(1);
    });

    test('stays while a failed transfer can be sent again', () async {
      when(
        () => balance.submitTopup(
          packId: any(named: 'packId'),
          method: any(named: 'method'),
          senderAccount: any(named: 'senderAccount'),
          screenshotPath: any(named: 'screenshotPath'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = build();
      await fillAndSubmit()(cubit);

      verifyNever(() => photos.discard(any()));
      await cubit.close();
      verify(() => photos.discard('/tmp/proof.jpg')).called(1);
    });
  });
}
