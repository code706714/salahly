import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/cubit/balance_cubit.dart';
import 'package:salahly/features/balance/presentation/pages/balance_page.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/balance_harness.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    BalanceHarness.registerFallbacks();
  });

  final topups = [
    testTopup(),
    testTopup(
      id: 'topup-2',
      uses: 1,
      amountPiastres: 2000,
      method: TopupMethod.wallet,
      status: TopupStatus.approved,
      createdAt: DateTime(2026, 10, 2, 9),
    ),
    testTopup(
      id: 'topup-3',
      status: TopupStatus.rejected,
      rejectReason: 'الصورة مش واضحة',
      createdAt: DateTime(2026, 10, 1, 9),
    ),
  ];
  final ledger = [
    testLedgerEntry(
      id: 4,
      delta: 5,
      reason: LedgerReason.topup,
      createdAt: DateTime(2026, 10, 4, 12),
    ),
    testLedgerEntry(id: 3),
    testLedgerEntry(
      id: 2,
      delta: 1,
      reason: LedgerReason.requestRefunded,
      createdAt: DateTime(2026, 10, 2, 12),
    ),
    testLedgerEntry(
      delta: 2,
      reason: LedgerReason.adminAdjustment,
      createdAt: DateTime(2026, 10, 1, 12),
    ),
    testLedgerEntry(
      id: 10,
      delta: 3,
      reason: LedgerReason.freeGrant,
      createdAt: DateTime(2026, 9, 30, 12),
    ),
    testLedgerEntry(
      id: 11,
      delta: 4,
      reason: LedgerReason.openingBalance,
      createdAt: DateTime(2026, 9, 29, 12),
    ),
  ];
  final loaded = BalanceState(
    status: BalanceStatus.ready,
    topups: topups,
    ledger: ledger,
  );

  BalanceHarness consumer({
    Honorific honorific = Honorific.ms,
    int credits = 2,
  }) => BalanceHarness(
    session: consumerWithCredits(honorific: honorific, credits: credits),
  );

  Future<void> pump(
    WidgetTester tester,
    BalanceHarness harness,
    BalanceState state, {
    UserRole role = UserRole.consumer,
    List<String> stubRoutes = const [],
  }) {
    when(() => harness.balance.state).thenReturn(state);
    return harness.pump(
      tester,
      BalanceView(role: role),
      stubRoutes: stubRoutes,
    );
  }

  group('for a consumer', () {
    testWidgets('shows the requests left and the transfers', (tester) async {
      await pump(tester, consumer(), loaded);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.balanceTitle), findsOneWidget);
      expect(find.text(l10n.consumerAccountCreditsTitle), findsOneWidget);
      expect(find.text(l10n.consumerAccountCredits(2)), findsOneWidget);
      expect(find.text(l10n.balanceBuy('ms')), findsOneWidget);
      expect(find.text(l10n.balanceTransfers), findsOneWidget);
      expect(find.text(l10n.buyUsesPackConsumer(5)), findsNWidgets(2));
      expect(find.text(l10n.buyUsesPackConsumer(1)), findsOneWidget);
      expect(find.text(l10n.pounds('80')), findsNWidgets(2));
      expect(find.text(l10n.pounds('20')), findsOneWidget);
      expect(
        find.text(
          '${l10n.buyUsesMethodInstapay} · '
          '${weekdayDate(DateTime(2026, 10, 4))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${l10n.buyUsesMethodWallet} · ${weekdayDate(DateTime(2026, 10, 2))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows each transfer waiting, added or turned down', (
      tester,
    ) async {
      await pump(tester, consumer(), loaded);

      expect(find.text(l10n.balanceStatusPending), findsOneWidget);
      expect(find.text(l10n.balanceStatusApproved), findsOneWidget);
      expect(find.text(l10n.balanceStatusRejected), findsOneWidget);
      expect(
        find.text(l10n.balanceRejectReason('الصورة مش واضحة')),
        findsOneWidget,
      );
    });

    testWidgets('shows what moved the balance', (tester) async {
      await pump(tester, consumer(), loaded);
      await tester.scrollUntilVisible(
        find.text(l10n.balanceLedgerOpeningBalance),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text(l10n.balanceLedger), findsOneWidget);
      expect(find.text(l10n.balanceLedgerTopup), findsOneWidget);
      expect(find.text(l10n.balanceLedgerRequestSent), findsOneWidget);
      expect(find.text(l10n.balanceLedgerRefunded), findsOneWidget);
      expect(find.text(l10n.balanceLedgerAdjustment), findsOneWidget);
      expect(find.text(l10n.balanceLedgerFreeGrant), findsOneWidget);
      expect(find.text(l10n.balanceLedgerOpeningBalance), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);
      expect(find.text(l10n.balanceLedgerOfferPicked), findsNothing);
    });

    testWidgets('says there is nothing yet', (tester) async {
      await pump(
        tester,
        consumer(),
        const BalanceState(status: BalanceStatus.ready),
      );

      expect(find.text(l10n.balanceTransfersEmpty('ms')), findsOneWidget);
      expect(find.text(l10n.balanceLedgerEmpty), findsOneWidget);
    });

    testWidgets('speaks to a man as a man', (tester) async {
      await pump(
        tester,
        consumer(honorific: Honorific.mr),
        const BalanceState(status: BalanceStatus.ready),
      );

      expect(find.text(l10n.balanceBuy('mr')), findsOneWidget);
      expect(find.text(l10n.balanceTransfersEmpty('mr')), findsOneWidget);
    });

    testWidgets('waits for the history', (tester) async {
      await pump(tester, consumer(), const BalanceState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.consumerAccountCredits(2)), findsOneWidget);
    });

    testWidgets('says when the history could not be fetched, and retries', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        const BalanceState(
          status: BalanceStatus.failed,
          failure: NetworkFailure(),
        ),
      );

      expect(find.text(l10n.balanceLoadFailed('ms')), findsOneWidget);
      expect(find.text(l10n.balanceTransfers), findsNothing);

      await tester.tap(find.text(l10n.retry));

      verify(harness.balance.load).called(1);
    });

    testWidgets('refreshes when pulled down', (tester) async {
      final harness = consumer();
      await pump(tester, harness, loaded);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      verify(harness.balance.load).called(1);
    });

    testWidgets('opens buying, and refreshes on the way back', (tester) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        loaded,
        stubRoutes: [AppRoutes.consumerBuyUses],
      );

      await tester.tap(find.text(l10n.balanceBuy('ms')));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.consumerBuyUses), findsOneWidget);
      verifyNever(harness.balance.load);

      Navigator.of(tester.element(find.text(AppRoutes.consumerBuyUses))).pop();
      await tester.pumpAndSettle();

      verify(harness.balance.load).called(1);
    });
  });

  group('for a technician', () {
    testWidgets('shows the jobs left and says what took one', (tester) async {
      final harness = BalanceHarness(session: technicianSession(credits: 3));
      await pump(tester, harness, loaded, role: UserRole.technician);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.balanceUsesTechnician), findsOneWidget);
      expect(find.text(l10n.balanceTechnicianCredits(3)), findsOneWidget);
      expect(find.text(l10n.balanceBuy('other')), findsOneWidget);
      expect(find.text(l10n.buyUsesPackTechnician(5)), findsNWidgets(2));
      await tester.scrollUntilVisible(
        find.text(l10n.balanceLedgerAdjustment),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(l10n.balanceLedgerOfferPicked), findsOneWidget);
      expect(find.text(l10n.balanceLedgerRequestSent), findsNothing);
    });

    testWidgets('opens the technician screen to buy', (tester) async {
      final harness = BalanceHarness(session: technicianSession());
      await pump(
        tester,
        harness,
        const BalanceState(status: BalanceStatus.ready),
        role: UserRole.technician,
        stubRoutes: [AppRoutes.technicianBuyUses],
      );

      await tester.tap(find.text(l10n.balanceBuy('other')));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianBuyUses), findsOneWidget);
    });

    testWidgets('says there is nothing yet, in the technician words', (
      tester,
    ) async {
      final harness = BalanceHarness(session: technicianSession(credits: 0));
      await pump(
        tester,
        harness,
        const BalanceState(status: BalanceStatus.ready),
        role: UserRole.technician,
      );

      expect(find.text(l10n.balanceTechnicianCredits(0)), findsOneWidget);
      expect(find.text(l10n.balanceTransfersEmpty('other')), findsOneWidget);
    });
  });
}
