import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/pages/escrow_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

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

  setUp(() {
    h = AdminHarness();
    when(
      () => h.files.signedUrl(any(), any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    when(
      () => h.escrows.fetchEscrows(
        status: any(named: 'status'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Ok(PagedResult(items: [], total: 0)));
  });

  void stubEscrows(Result<PagedResult<EscrowReview>> result) => when(
    () => h.escrows.fetchEscrows(
      status: any(named: 'status'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  void stubOne(EscrowReview escrow) =>
      stubEscrows(Ok(PagedResult(items: [escrow], total: 1)));

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const EscrowPage(),
    path: AdminRoutes.escrow,
    size: const Size(1440, 1800),
    settle: settle,
  );

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('نورهان محمد'));
    await tester.pumpAndSettle();
  }

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Future<void> writeInDialog(WidgetTester tester, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      text,
    );
    await tester.pump();
  }

  Future<void> tickAll(WidgetTester tester) async {
    for (final box in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
    }
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('shows a spinner while it loads', (tester) async {
      final pending = Completer<Result<PagedResult<EscrowReview>>>();
      when(
        () => h.escrows.fetchEscrows(
          status: any(named: 'status'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => pending.future);

      await pump(tester, settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says nothing is waiting when it is empty', (tester) async {
      await pump(tester);

      expect(find.text(l10n.adminEscrowEmpty), findsOneWidget);
      expect(find.text(l10n.adminEscrowPickOne), findsOneWidget);
    });

    testWidgets('says why it did not load and tries again', (tester) async {
      stubEscrows(const Err(NetworkFailure()));
      await pump(tester);

      stubOne(testEscrowReview());
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text('نورهان محمد'), findsOneWidget);
    });

    testWidgets('names an account that was deleted', (tester) async {
      stubOne(testEscrowReview(consumerName: null));

      await pump(tester);

      expect(find.text(l10n.adminDeletedAccount), findsOneWidget);
    });

    for (final (label, status) in <(String, EscrowStatus?)>[
      ('adminEscrowTabDisputed', EscrowStatus.disputed),
      ('adminEscrowTabRefundDue', EscrowStatus.refundDue),
      ('adminEscrowTabAll', null),
    ]) {
      testWidgets('narrows the list by the $label tab', (tester) async {
        await pump(tester);
        final text = switch (label) {
          'adminEscrowTabDisputed' => l10n.adminEscrowTabDisputed,
          'adminEscrowTabRefundDue' => l10n.adminEscrowTabRefundDue,
          _ => l10n.adminEscrowTabAll,
        };

        await tester.tap(find.text(text));
        await tester.pumpAndSettle();

        verify(
          () => h.escrows.fetchEscrows(
            status: status,
            limit: any(named: 'limit'),
            offset: 0,
          ),
        ).called(1);
      });
    }
  });

  group('checking a transfer', () {
    testWidgets('opens it with who paid, how much and from where', (
      tester,
    ) async {
      stubOne(testEscrowReview());
      await pump(tester);

      await open(tester);

      expect(find.text(l10n.adminEscrowScreenshot), findsWidgets);
      expect(find.text('norhan@instapay'), findsOneWidget);
      expect(find.text('محمود سعيد'), findsWidgets);
      expect(find.text(l10n.adminEscrowStatusPending), findsOneWidget);
    });

    testWidgets('approves after every check is ticked and confirmed', (
      tester,
    ) async {
      stubOne(testEscrowReview());
      when(
        () => h.escrows.approve('escrow-1'),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await open(tester);

      FilledButton approve() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, l10n.adminEscrowApprove),
      );
      expect(approve().onPressed, isNull);

      await tickAll(tester);
      await tester.tap(find.text(l10n.adminEscrowApprove));
      await tester.pumpAndSettle();
      verifyNever(() => h.escrows.approve(any()));
      await tester.tap(find.text(l10n.adminEscrowApproveConfirm));
      await tester.pumpAndSettle();

      verify(() => h.escrows.approve('escrow-1')).called(1);
      expect(find.text(l10n.adminEscrowApproved), findsOneWidget);
      expect(find.text(l10n.adminEscrowPickOne), findsOneWidget);
    });

    testWidgets('rejects with a reason the consumer will read', (tester) async {
      stubOne(testEscrowReview());
      when(
        () => h.escrows.reject(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminVerifyReject));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.adminTopupsReasonAmount));
      await tester.pump();
      await tester.tap(inDialog(l10n.adminTopupsRejectConfirm));
      await tester.pumpAndSettle();

      verify(
        () => h.escrows.reject('escrow-1', l10n.adminTopupsReasonAmount),
      ).called(1);
      expect(find.text(l10n.adminEscrowRejected), findsOneWidget);
    });

    testWidgets('asks for a fresh sign in before holding money', (
      tester,
    ) async {
      stubOne(testEscrowReview());
      when(
        () => h.escrows.approve(any()),
      ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure()));
      await pump(tester);
      await open(tester);
      await tickAll(tester);

      await tester.tap(find.text(l10n.adminEscrowApprove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.adminEscrowApproveConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminReloginTitle), findsOneWidget);
    });

    testWidgets('reloads the list when the transfer was reviewed already', (
      tester,
    ) async {
      stubOne(testEscrowReview());
      when(
        () => h.escrows.approve(any()),
      ).thenAnswer((_) async => const Err(NotPendingFailure()));
      await pump(tester);
      await open(tester);
      await tickAll(tester);

      await tester.tap(find.text(l10n.adminEscrowApprove));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.adminEscrowApproveConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminErrorNotPending), findsOneWidget);
      verify(
        () => h.escrows.fetchEscrows(
          status: EscrowStatus.pending,
          limit: any(named: 'limit'),
          offset: 0,
        ),
      ).called(2);
    });
  });

  group('settling a dispute', () {
    EscrowReview disputed() => testEscrowReview(
      status: EscrowStatus.disputed,
      disputeReason: 'الفني ماجاش',
      disputedBy: EscrowDisputer.consumer,
    );

    setUp(
      () => when(
        () => h.escrows.resolve(
          any(),
          payTechnician: any(named: 'payTechnician'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => const Ok(null)),
    );

    testWidgets("shows the consumer's complaint", (tester) async {
      stubOne(disputed());
      await pump(tester);

      await open(tester);

      expect(
        find.text(l10n.adminEscrowDisputeByConsumer('الفني ماجاش')),
        findsOneWidget,
      );
    });

    testWidgets("shows the technician's complaint", (tester) async {
      stubOne(
        testEscrowReview(
          status: EscrowStatus.disputed,
          disputeReason: 'العميل مش بيرد',
          disputedBy: EscrowDisputer.technician,
        ),
      );
      await pump(tester);

      await open(tester);

      expect(
        find.text(l10n.adminEscrowDisputeByTechnician('العميل مش بيرد')),
        findsOneWidget,
      );
    });

    testWidgets('decides for the technician with a note', (tester) async {
      stubOne(disputed());
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminEscrowResolveTechnician));
      await tester.pumpAndSettle();
      await writeInDialog(tester, 'الفني على حق');
      await tester.tap(inDialog(l10n.adminEscrowResolveTechnicianConfirm));
      await tester.pumpAndSettle();

      verify(
        () => h.escrows.resolve(
          'escrow-1',
          payTechnician: true,
          note: 'الفني على حق',
        ),
      ).called(1);
      expect(find.text(l10n.adminEscrowResolved), findsOneWidget);
    });

    testWidgets('decides for the consumer with a note', (tester) async {
      stubOne(disputed());
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminEscrowResolveConsumer));
      await tester.pumpAndSettle();
      await writeInDialog(tester, 'الفني ماجاش فعلاً');
      await tester.tap(inDialog(l10n.adminEscrowResolveConsumerConfirm));
      await tester.pumpAndSettle();

      verify(
        () => h.escrows.resolve(
          'escrow-1',
          payTechnician: false,
          note: 'الفني ماجاش فعلاً',
        ),
      ).called(1);
    });
  });

  group('returning the money', () {
    testWidgets('records the reference of the refund', (tester) async {
      stubOne(testEscrowReview(status: EscrowStatus.refundDue));
      when(
        () => h.escrows.markRefunded(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminEscrowRefundAction));
      await tester.pumpAndSettle();
      expect(
        inDialog(l10n.adminEscrowRefundBody('350', 'norhan@instapay')),
        findsOneWidget,
      );
      await writeInDialog(tester, 'IP-999');
      await tester.tap(inDialog(l10n.adminEscrowRefundConfirm));
      await tester.pumpAndSettle();

      verify(() => h.escrows.markRefunded('escrow-1', 'IP-999')).called(1);
      expect(find.text(l10n.adminEscrowRefunded), findsOneWidget);
    });
  });

  group('an online payment', () {
    testWidgets('shows how it was paid and no screenshot', (tester) async {
      stubOne(testEscrowReview(status: EscrowStatus.held, online: true));
      await pump(tester);
      await open(tester);

      expect(find.text(l10n.adminEscrowOnline('card')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('is refunded through the provider', (tester) async {
      stubOne(testEscrowReview(status: EscrowStatus.refundDue, online: true));
      when(
        () => h.escrows.refundOnline(any()),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminEscrowRefundOnlineAction));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(l10n.adminEscrowRefundOnlineConfirm));
      await tester.pumpAndSettle();

      verify(() => h.escrows.refundOnline('escrow-1')).called(1);
      expect(find.text(l10n.adminEscrowRefunded), findsOneWidget);
    });

    testWidgets('says to refund from the provider dashboard when needed', (
      tester,
    ) async {
      stubOne(testEscrowReview(status: EscrowStatus.refundDue, online: true));
      when(
        () => h.escrows.refundOnline(any()),
      ).thenAnswer((_) async => const Err(RefundByDashboardFailure()));
      await pump(tester);
      await open(tester);

      await tester.tap(find.text(l10n.adminEscrowRefundOnlineAction));
      await tester.pumpAndSettle();
      await tester.tap(inDialog(l10n.adminEscrowRefundOnlineConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminEscrowRefundByDashboard), findsOneWidget);
    });

    testWidgets('does not offer the provider refund for an old transfer', (
      tester,
    ) async {
      stubOne(testEscrowReview(status: EscrowStatus.refundDue));
      await pump(tester);
      await open(tester);

      expect(find.text(l10n.adminEscrowRefundOnlineAction), findsNothing);
      expect(find.text(l10n.adminEscrowRefundAction), findsOneWidget);
    });
  });

  testWidgets('shows the reason a transfer was rejected, as plain text', (
    tester,
  ) async {
    stubOne(
      testEscrowReview(
        status: EscrowStatus.rejected,
        rejectReason: '<script>x</script>',
      ),
    );
    await pump(tester);

    await open(tester);

    expect(
      find.text(l10n.adminTopupsRejectedReason('<script>x</script>')),
      findsOneWidget,
    );
    expect(find.text(l10n.adminEscrowApprove), findsNothing);
  });
}
