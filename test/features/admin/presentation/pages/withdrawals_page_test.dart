import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/presentation/pages/withdrawals_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../pump_app.dart';

void main() {
  late AdminHarness h;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    AdminHarness.registerFallbacks();
  });

  void stubWithdrawals(Result<PagedResult<WithdrawalReview>> result) => when(
    () => h.withdrawals.fetchWithdrawals(
      status: any(named: 'status'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  setUp(() {
    h = AdminHarness();
    stubWithdrawals(const Ok(PagedResult(items: [], total: 0)));
  });

  void stubOne(WithdrawalReview withdrawal) =>
      stubWithdrawals(Ok(PagedResult(items: [withdrawal], total: 1)));

  Future<void> pump(WidgetTester tester) => h.pump(
    tester,
    const WithdrawalsPage(),
    path: AdminRoutes.withdrawals,
    size: const Size(1440, 1800),
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('محمود سعيد'));
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('says nothing is waiting when it is empty', (tester) async {
    await pump(tester);

    expect(find.text(l10n.adminWithdrawalsEmpty), findsOneWidget);
    expect(find.text(l10n.adminWithdrawalsPickOne), findsOneWidget);
  });

  testWidgets('says why it did not load and tries again', (tester) async {
    stubWithdrawals(const Err(NetworkFailure()));
    await pump(tester);

    stubOne(testWithdrawalReview());
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('محمود سعيد'), findsOneWidget);
  });

  for (final (text, status) in <(String Function(), WithdrawalStatus?)>[
    (() => l10n.adminWithdrawalsTabPaid, WithdrawalStatus.paid),
    (() => l10n.adminWithdrawalsTabRejected, WithdrawalStatus.rejected),
    (() => l10n.adminWithdrawalsTabAll, null),
  ]) {
    testWidgets('narrows the list to ${status ?? 'all'}', (tester) async {
      await pump(tester);

      await tester.tap(find.text(text()));
      await tester.pumpAndSettle();

      verify(
        () => h.withdrawals.fetchWithdrawals(
          status: status,
          limit: any(named: 'limit'),
          offset: 0,
        ),
      ).called(1);
    });
  }

  testWidgets('shows where to send the money and to whom', (tester) async {
    stubOne(testWithdrawalReview());
    await pump(tester);

    await open(tester);

    expect(find.text('01005551234'), findsOneWidget);
    expect(find.text(l10n.adminWithdrawalPayAction), findsOneWidget);
    expect(find.text(l10n.adminWithdrawalRejectAction), findsOneWidget);
  });

  testWidgets('records the reference of the transfer', (tester) async {
    stubOne(testWithdrawalReview());
    when(
      () => h.withdrawals.markPaid(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);
    await open(tester);

    await tester.tap(find.text(l10n.adminWithdrawalPayAction));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'IP-123',
    );
    await tester.pump();
    await tester.tap(inDialog(l10n.adminWithdrawalPayConfirm));
    await tester.pumpAndSettle();

    verify(() => h.withdrawals.markPaid('withdrawal-1', 'IP-123')).called(1);
    expect(find.text(l10n.adminWithdrawalPaid), findsOneWidget);
  });

  testWidgets('rejects with a reason the technician reads', (tester) async {
    stubOne(testWithdrawalReview());
    when(
      () => h.withdrawals.reject(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);
    await open(tester);

    await tester.tap(find.text(l10n.adminWithdrawalRejectAction));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminWithdrawalReasonAccount));
    await tester.pump();
    await tester.tap(inDialog(l10n.adminWithdrawalRejectConfirm));
    await tester.pumpAndSettle();

    verify(
      () => h.withdrawals.reject(
        'withdrawal-1',
        l10n.adminWithdrawalReasonAccount,
      ),
    ).called(1);
    expect(find.text(l10n.adminWithdrawalRejected), findsOneWidget);
  });

  testWidgets('shows the reference once paid and offers nothing more', (
    tester,
  ) async {
    stubOne(
      testWithdrawalReview(
        status: WithdrawalStatus.paid,
        reference: 'IP-123',
      ),
    );
    await pump(tester);

    await open(tester);

    expect(
      find.text(l10n.adminWithdrawalPaidReference('IP-123')),
      findsOneWidget,
    );
    expect(find.text(l10n.adminWithdrawalPayAction), findsNothing);
  });

  testWidgets('shows the reason as plain text once rejected', (tester) async {
    stubOne(
      testWithdrawalReview(
        status: WithdrawalStatus.rejected,
        rejectReason: '<script>x</script>',
      ),
    );
    await pump(tester);

    await open(tester);

    expect(
      find.text(l10n.adminTopupsRejectedReason('<script>x</script>')),
      findsOneWidget,
    );
  });
}
