import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/pages/verification_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';

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
      () => h.verification.fetchDetail(any()),
    ).thenAnswer((_) async => Ok(testVerificationDetail()));
  });

  void stubQueue(Result<PagedResult<VerificationSummary>> result) => when(
    () => h.verification.fetchQueue(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const VerificationPage(),
    path: AdminRoutes.verification,
    size: const Size(1440, 1800),
    settle: settle,
  );

  // The reject button and the dialog's confirm button read the same.
  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Future<void> openFirst(WidgetTester tester) async {
    await tester.tap(find.text('نورهان محمد'));
    await tester.pumpAndSettle();
  }

  Future<void> tickAll(WidgetTester tester) async {
    for (final box in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
    }
    await tester.pumpAndSettle();
  }

  void stubQueueWithOne() => stubQueue(
    Ok(PagedResult(items: [testVerificationSummary()], total: 1)),
  );

  testWidgets('shows a spinner while the queue loads', (tester) async {
    final pending = Completer<Result<PagedResult<VerificationSummary>>>();
    when(
      () => h.verification.fetchQueue(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says nobody is waiting when the queue is empty', (
    tester,
  ) async {
    stubQueue(const Ok(PagedResult(items: [], total: 0)));

    await pump(tester);

    expect(find.text(l10n.adminVerifyEmptyPending), findsOneWidget);
    expect(find.text(l10n.adminVerifyPickOne), findsOneWidget);
  });

  testWidgets('says why the queue did not load and tries again', (
    tester,
  ) async {
    stubQueue(const Err(NetworkFailure()));
    await pump(tester);
    expect(find.text(l10n.retry), findsOneWidget);

    stubQueueWithOne();
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('نورهان محمد'), findsOneWidget);
  });

  testWidgets('narrows the queue by the tab picked', (tester) async {
    stubQueueWithOne();
    await pump(tester);

    await tester.tap(find.text(l10n.adminVerifyTabRejected));
    await tester.pumpAndSettle();

    verify(
      () => h.verification.fetchQueue(
        VerificationStatus.rejected,
        limit: any(named: 'limit'),
        offset: 0,
      ),
    ).called(1);
  });

  testWidgets('opens a submission with its photos and facts', (tester) async {
    stubQueueWithOne();
    await pump(tester);

    await openFirst(tester);

    verify(() => h.verification.fetchDetail('ver-1')).called(1);
    expect(find.text('ورشة النور'), findsOneWidget);
    expect(find.text(l10n.adminVerifyIdFront), findsWidgets);
    expect(find.text(l10n.adminVerifySelfie), findsWidgets);
    // A link that could not be made says so instead of a broken picture.
    expect(find.text(l10n.adminImageFailed), findsNWidgets(3));
  });

  testWidgets('says why a submission did not open', (tester) async {
    stubQueueWithOne();
    when(
      () => h.verification.fetchDetail(any()),
    ).thenAnswer((_) async => const Err(AdminNotFoundFailure()));
    await pump(tester);

    await openFirst(tester);

    expect(find.text(l10n.adminErrorNotFound), findsOneWidget);
  });

  testWidgets('keeps approve off until every check is ticked', (tester) async {
    stubQueueWithOne();
    await pump(tester);
    await openFirst(tester);

    FilledButton approve() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.adminVerifyApprove),
    );
    expect(approve().onPressed, isNull);

    await tickAll(tester);

    expect(approve().onPressed, isNotNull);
  });

  testWidgets('approves after the admin confirms', (tester) async {
    stubQueueWithOne();
    when(
      () => h.verification.approve('ver-1'),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);
    await openFirst(tester);
    await tickAll(tester);

    await tester.tap(find.text(l10n.adminVerifyApprove));
    await tester.pumpAndSettle();
    verifyNever(() => h.verification.approve(any()));
    expect(
      find.text(l10n.adminVerifyApproveTitle('نورهان محمد')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.adminVerifyApproveConfirm));
    await tester.pumpAndSettle();

    verify(() => h.verification.approve('ver-1')).called(1);
    expect(find.text(l10n.adminVerifyApproved), findsOneWidget);
    // The queue was loaded again without it.
    verify(
      () => h.verification.fetchQueue(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).called(2);
  });

  testWidgets('does not approve when the admin cancels', (tester) async {
    stubQueueWithOne();
    await pump(tester);
    await openFirst(tester);
    await tickAll(tester);

    await tester.tap(find.text(l10n.adminVerifyApprove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminCancel));
    await tester.pumpAndSettle();

    verifyNever(() => h.verification.approve(any()));
  });

  testWidgets('rejects only with a reason of enough letters', (tester) async {
    stubQueueWithOne();
    when(
      () => h.verification.reject(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);
    await openFirst(tester);

    await tester.tap(find.text(l10n.adminVerifyReject));
    await tester.pumpAndSettle();
    TextButton confirm() => tester.widget<TextButton>(
      find.ancestor(
        of: inDialog(l10n.adminVerifyRejectConfirm),
        matching: find.byType(TextButton),
      ),
    );
    expect(confirm().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump();
    expect(confirm().onPressed, isNull);

    await tester.tap(find.text(l10n.adminVerifyReasonBlurry));
    await tester.pump();
    expect(confirm().onPressed, isNotNull);

    await tester.tap(inDialog(l10n.adminVerifyRejectConfirm));
    await tester.pumpAndSettle();

    verify(
      () => h.verification.reject('ver-1', l10n.adminVerifyReasonBlurry),
    ).called(1);
    expect(find.text(l10n.adminVerifyRejected), findsOneWidget);
  });

  testWidgets('says so when someone else reviewed it first', (tester) async {
    stubQueueWithOne();
    when(
      () => h.verification.approve(any()),
    ).thenAnswer((_) async => const Err(NotPendingFailure()));
    await pump(tester);
    await openFirst(tester);
    await tickAll(tester);

    await tester.tap(find.text(l10n.adminVerifyApprove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminVerifyApproveConfirm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminErrorNotPending), findsOneWidget);
  });

  testWidgets('asks for a fresh sign in when the server wants one', (
    tester,
  ) async {
    stubQueueWithOne();
    when(
      () => h.verification.approve(any()),
    ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure()));
    await pump(tester);
    await openFirst(tester);
    await tickAll(tester);

    await tester.tap(find.text(l10n.adminVerifyApprove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminVerifyApproveConfirm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminReloginTitle), findsOneWidget);

    // Backing out does not repeat the change.
    await tester.tap(find.text(l10n.adminReloginCancel));
    await tester.pumpAndSettle();
    verify(() => h.verification.approve('ver-1')).called(1);
  });

  testWidgets('shows a rejected submission with its reason and no buttons', (
    tester,
  ) async {
    stubQueue(
      Ok(
        PagedResult(
          items: [
            testVerificationSummary(status: VerificationStatus.rejected),
          ],
          total: 1,
        ),
      ),
    );
    when(() => h.verification.fetchDetail(any())).thenAnswer(
      (_) async => Ok(
        testVerificationDetail(
          status: VerificationStatus.rejected,
          rejectionReason: 'الصورة <i>مش</i> واضحة',
        ),
      ),
    );
    await pump(tester);
    await tester.tap(find.text(l10n.adminVerifyTabRejected));
    await tester.pumpAndSettle();

    await openFirst(tester);

    // The reason is shown as it was written, not as markup.
    expect(
      find.text(l10n.adminVerifyRejectedReason('الصورة <i>مش</i> واضحة')),
      findsOneWidget,
    );
    expect(find.text(l10n.adminVerifyApprove), findsNothing);
  });
}
