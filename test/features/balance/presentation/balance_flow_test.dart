import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/pages/balance_page.dart';
import 'package:salahly/features/balance/presentation/pages/buy_uses_page.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/presentation/pages/payment_page.dart';

import '../../../helpers/balance_fixtures.dart';
import '../../../helpers/consumer_app.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

/// Pays the picked pack: the server starts the payment, the provider page
/// opens, and the server then confirms it.
Future<void> _payAndConfirm(
  WidgetTester tester,
  MockPaymentRepository payments,
  Future<void> Function(WidgetTester) settle, {
  required String honorific,
  required int amountPiastres,
  void Function()? onPaid,
}) async {
  when(
    () => payments.startCreditPackPayment(
      packId: any(named: 'packId'),
      expectedPricePiastres: any(named: 'expectedPricePiastres'),
    ),
  ).thenAnswer(
    (_) async => Ok(
      PaymentCheckout(
        orderId: 'order-1',
        url: Uri.parse('https://pay.example/checkout'),
        amountPiastres: amountPiastres,
      ),
    ),
  );
  when(() => payments.fetchOrder('order-1')).thenAnswer((_) async {
    onPaid?.call();
    return const Ok(
      PaymentOrder(id: 'order-1', status: PaymentStatus.succeeded),
    );
  });

  await tester.tap(
    find.text(l10n.buyUsesPay(honorific, formatPounds(amountPiastres))),
  );
  await settle(tester);
  await tester.pump(const Duration(seconds: 3));
  await settle(tester);
  await tester.tap(find.text(l10n.paymentDone));
  await settle(tester);
  await tester.pump(const Duration(seconds: 1));
  await settle(tester);
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
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

    testConsumerApp('buys a pack from the balance and sees it added', (
      tester,
      app,
    ) async {
      await app.pump(tester, location: AppRoutes.consumerBalance);
      await tester.tap(find.text(l10n.balanceBuy('ms')));
      await app.settle(tester);
      expect(find.byType(BuyUsesPage), findsOneWidget);

      await _payAndConfirm(
        tester,
        app.payments,
        app.settle,
        honorific: 'ms',
        amountPiastres: 8000,
      );

      verify(
        () => app.payments.startCreditPackPayment(
          packId: 'pack-5',
          expectedPricePiastres: 8000,
        ),
      ).called(1);
      verify(
        () => app.apps.openLink(Uri.parse('https://pay.example/checkout')),
      ).called(1);
      expect(tester.takeException(), isNull);
      expect(find.byType(PaymentPage), findsNothing);
      expect(find.byType(BuyUsesPage), findsNothing);
      expect(find.byType(BalancePage), findsOneWidget);
      verify(() => app.account.fetchProfile(any())).called(greaterThan(2));
    });

    testConsumerApp('stays on the packs when the payment is left unpaid', (
      tester,
      app,
    ) async {
      when(
        () => app.payments.startCreditPackPayment(
          packId: any(named: 'packId'),
          expectedPricePiastres: any(named: 'expectedPricePiastres'),
        ),
      ).thenAnswer(
        (_) async => Ok(
          PaymentCheckout(
            orderId: 'order-1',
            url: Uri.parse('https://pay.example/checkout'),
            amountPiastres: 8000,
          ),
        ),
      );
      when(() => app.payments.fetchOrder('order-1')).thenAnswer(
        (_) async => const Ok(
          PaymentOrder(id: 'order-1', status: PaymentStatus.failed),
        ),
      );
      await app.pump(tester, location: AppRoutes.consumerBalance);
      await tester.tap(find.text(l10n.balanceBuy('ms')));
      await app.settle(tester);

      await tester.tap(
        find.text(l10n.buyUsesPay('ms', formatPounds(8000))),
      );
      await app.settle(tester);
      await tester.pump(const Duration(seconds: 3));
      await app.settle(tester);
      expect(find.text(l10n.paymentFailedTitle), findsOneWidget);
      await tester.tap(find.text(l10n.paymentBack));
      await app.settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(BuyUsesPage), findsOneWidget);
      expect(find.text(l10n.buyUsesPaid), findsNothing);
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

        await _payAndConfirm(
          tester,
          app.payments,
          app.settle,
          honorific: 'other',
          amountPiastres: 8000,
        );

        expect(find.byType(BalancePage), findsOneWidget);
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

    testTechnicianApp('sees the balance after paying', (tester, app) async {
      await app.pump(tester);
      await tester.tap(find.text(l10n.balanceBuy('other')));
      await app.settle(tester);

      await _payAndConfirm(
        tester,
        app.payments,
        app.settle,
        honorific: 'other',
        amountPiastres: 25000,
      );

      verify(
        () => app.payments.startCreditPackPayment(
          packId: 'pack-t10',
          expectedPricePiastres: 25000,
        ),
      ).called(1);
      expect(find.byType(BalancePage), findsOneWidget);
    });
  });
}
