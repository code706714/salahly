import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/pages/balance_page.dart';
import 'package:salahly/features/balance/presentation/pages/buy_uses_page.dart';

import '../../../helpers/balance_fixtures.dart';
import '../../../helpers/consumer_app.dart';
import '../../../helpers/follow_up_harness.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

/// Types the sender, picks the screenshot from the gallery and sends.
Future<void> _fillAndSend(
  WidgetTester tester,
  MockBalanceRepository balance,
  MockPhotoPicker photoPicker,
  Future<void> Function(WidgetTester) settle, {
  required String honorific,
  void Function()? onSubmit,
}) async {
  when(
    () => photoPicker.pick(
      source: any(named: 'source'),
      purpose: any(named: 'purpose'),
    ),
  ).thenAnswer((_) async => '/tmp/proof.jpg');
  when(
    () => balance.uploadScreenshot(any()),
  ).thenAnswer((_) async => const Ok('user-1/proof.jpg'));
  when(
    () => balance.submitTopup(
      packId: any(named: 'packId'),
      method: any(named: 'method'),
      senderAccount: any(named: 'senderAccount'),
      screenshotPath: any(named: 'screenshotPath'),
      expectedPricePiastres: any(named: 'expectedPricePiastres'),
    ),
  ).thenAnswer((_) async {
    onSubmit?.call();
    return const Ok('topup-1');
  });

  await reveal(tester, find.byType(TextField));
  await tester.enterText(find.byType(TextField), '٠١١١ ٤٥٦ ٧٧٢٠');
  final add = find.text(l10n.buyUsesScreenshotAdd(honorific));
  await reveal(tester, add);
  await tester.tap(add);
  await settle(tester);
  await tester.tap(find.text(l10n.complaintPhotoChoose(honorific)));
  await settle(tester);
  await tester.tap(find.text(l10n.buyUsesSubmit(honorific)));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(PhotoPurpose.transfer);
  });

  group('a consumer', () {
    testConsumerApp('opens the balance from her account card', (
      tester,
      app,
    ) async {
      when(() => app.balance.fetchTopups(any())).thenAnswer(
        (_) async => Ok([
          testTopup(status: TopupStatus.rejected, rejectReason: 'مش واضحة'),
        ]),
      );
      await app.pump(tester, location: AppRoutes.consumerAccount);

      await tester.tap(find.text(l10n.consumerAccountCreditsTitle));
      await app.settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(BalancePage), findsOneWidget);
      expect(find.text(l10n.balanceStatusRejected), findsOneWidget);
      expect(find.text(l10n.balanceRejectReason('مش واضحة')), findsOneWidget);
      verify(() => app.balance.fetchTopups(any())).called(1);
      verify(() => app.account.fetchProfile(any())).called(2);
    });

    testConsumerApp('buys a pack from the balance and sees it waiting', (
      tester,
      app,
    ) async {
      var sent = false;
      when(
        () => app.balance.fetchTopups(any()),
      ).thenAnswer((_) async => Ok(sent ? [testTopup()] : []));
      await app.pump(tester, location: AppRoutes.consumerBalance);
      await tester.tap(find.text(l10n.balanceBuy('ms')));
      await app.settle(tester);
      expect(find.byType(BuyUsesPage), findsOneWidget);

      await _fillAndSend(
        tester,
        app.balance,
        app.photoPicker,
        app.settle,
        honorific: 'ms',
        onSubmit: () => sent = true,
      );

      verifyInOrder([
        () => app.balance.uploadScreenshot('/tmp/proof.jpg'),
        () => app.balance.submitTopup(
          packId: 'pack-5',
          method: TopupMethod.instapay,
          senderAccount: '01114567720',
          screenshotPath: 'user-1/proof.jpg',
          expectedPricePiastres: 8000,
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(find.byType(BuyUsesPage), findsNothing);
      expect(find.byType(BalancePage), findsOneWidget);
      expect(find.text(l10n.buyUsesSent), findsOneWidget);
      expect(find.text(l10n.balanceStatusPending), findsOneWidget);
      verify(() => app.account.fetchProfile(any())).called(greaterThan(2));
    });

    testConsumerApp(
      'is offered to buy on home when one request is left',
      (
        tester,
        app,
      ) async {
        await app.pump(tester);

        await tester.tap(find.text(l10n.buyUsesTopUp('ms')));
        await app.settle(tester);

        expect(find.byType(BuyUsesPage), findsOneWidget);
        expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsOneWidget);
      },
      app: () => ConsumerApp(requestCredits: 1),
    );

    testConsumerApp(
      'is offered to buy on home when none are left',
      (
        tester,
        app,
      ) async {
        await app.pump(tester);

        expect(find.text(l10n.consumerCreditsLeft(0)), findsOneWidget);
        expect(find.text(l10n.buyUsesTopUp('ms')), findsOneWidget);
      },
      app: () => ConsumerApp(requestCredits: 0),
    );

    testConsumerApp('is not pushed to buy while she has requests left', (
      tester,
      app,
    ) async {
      await app.pump(tester);

      expect(find.text(l10n.buyUsesTopUp('ms')), findsNothing);
    });

    testConsumerApp(
      'sees the balance after buying from home',
      (
        tester,
        app,
      ) async {
        await app.pump(tester);
        await tester.tap(find.text(l10n.buyUsesTopUp('other')));
        await app.settle(tester);

        await _fillAndSend(
          tester,
          app.balance,
          app.photoPicker,
          app.settle,
          honorific: 'other',
        );

        expect(find.byType(BalancePage), findsOneWidget);
        expect(find.text(l10n.buyUsesSent), findsOneWidget);
      },
      app: () => ConsumerApp(honorific: Honorific.mr, requestCredits: 0),
    );
  });

  group('a technician', () {
    testTechnicianApp('buys from the credits row on today', (
      tester,
      app,
    ) async {
      await app.pump(tester);

      await tester.tap(find.text(l10n.balanceBuy('other')));
      await app.settle(tester);

      expect(find.byType(BuyUsesPage), findsOneWidget);
      expect(find.text(l10n.buyUsesTitleTechnician), findsOneWidget);
      verify(() => app.balance.fetchPacks(any())).called(1);
    });

    testTechnicianApp('opens the balance from the account', (
      tester,
      app,
    ) async {
      when(
        () => app.balance.fetchLedger(any()),
      ).thenAnswer((_) async => Ok([testLedgerEntry()]));
      await app.pump(tester, location: AppRoutes.technicianAccount);

      await tester.tap(find.text(l10n.balanceTitle));
      await app.settle(tester);

      expect(find.byType(BalancePage), findsOneWidget);
      expect(find.text(l10n.balanceUsesTechnician), findsOneWidget);
      expect(find.text(l10n.balanceLedgerOfferPicked), findsOneWidget);
    });

    testTechnicianApp('sees the balance after buying', (tester, app) async {
      await app.pump(tester);
      await tester.tap(find.text(l10n.balanceBuy('other')));
      await app.settle(tester);

      await _fillAndSend(
        tester,
        app.balance,
        app.photoPicker,
        app.settle,
        honorific: 'other',
      );

      verify(
        () => app.balance.submitTopup(
          packId: 'pack-t10',
          method: TopupMethod.instapay,
          senderAccount: '01114567720',
          screenshotPath: 'user-1/proof.jpg',
          expectedPricePiastres: 25000,
        ),
      ).called(1);
      expect(find.byType(BalancePage), findsOneWidget);
      expect(find.text(l10n.buyUsesSent), findsOneWidget);
    });
  });
}
