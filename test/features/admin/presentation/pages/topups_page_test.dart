import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/presentation/pages/topups_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../pump_app.dart';

void main() {
  late AdminHarness h;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    AdminHarness.registerFallbacks();
    registerFallbackValue(PhoneNumber.tryParse('1002345678'));
    registerFallbackValue(OtpChannel.whatsapp);
  });

  setUp(() {
    h = AdminHarness();
    when(
      () => h.files.signedUrl(any(), any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
  });

  void stubTopups(Result<PagedResult<TopupReview>> result) => when(
    () => h.topups.fetchTopups(
      status: any(named: 'status'),
      role: any(named: 'role'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const TopupsPage(),
    path: AdminRoutes.transfers,
    size: const Size(1440, 1800),
    settle: settle,
  );

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  Future<void> open(WidgetTester tester, {String name = 'سامي حسن'}) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  Future<void> tickAll(WidgetTester tester) async {
    for (final box in find.byType(CheckboxListTile).evaluate().toList()) {
      await tester.tap(find.byWidget(box.widget));
    }
    await tester.pumpAndSettle();
  }

  void stubOne({TopupReview? topup}) => stubTopups(
    Ok(PagedResult(items: [topup ?? testTopupReview()], total: 1)),
  );

  testWidgets('shows a spinner while the transfers load', (tester) async {
    final pending = Completer<Result<PagedResult<TopupReview>>>();
    when(
      () => h.topups.fetchTopups(
        status: any(named: 'status'),
        role: any(named: 'role'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says nothing is waiting when the list is empty', (tester) async {
    stubTopups(const Ok(PagedResult(items: [], total: 0)));

    await pump(tester);

    expect(find.text(l10n.adminTopupsEmptyPending), findsOneWidget);
    expect(find.text(l10n.adminTopupsPickOne), findsOneWidget);
  });

  testWidgets('says why the list did not load and tries again', (tester) async {
    stubTopups(const Err(NetworkFailure()));
    await pump(tester);

    stubOne();
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('سامي حسن'), findsOneWidget);
  });

  testWidgets('names an account that was deleted', (tester) async {
    stubOne(topup: testTopupReview(name: null, accountPhone: null));

    await pump(tester);

    expect(find.text(l10n.adminDeletedAccount), findsOneWidget);
  });

  testWidgets('narrows the list by the tab picked', (tester) async {
    stubOne();
    await pump(tester);

    await tester.tap(find.text(l10n.adminTopupsTabAll));
    await tester.pumpAndSettle();

    verify(
      () => h.topups.fetchTopups(
        status: null,
        role: null,
        limit: any(named: 'limit'),
        offset: 0,
      ),
    ).called(1);
  });

  testWidgets('opens a transfer with what to compare it against', (
    tester,
  ) async {
    stubOne();
    await pump(tester);

    await open(tester);

    expect(find.text(l10n.adminTopupsScreenshot), findsWidgets);
    expect(find.text(l10n.adminTopupsAmount), findsOneWidget);
    expect(find.text(l10n.adminTopupsDifferentSender), findsNothing);
    expect(find.text(l10n.adminImageFailed), findsOneWidget);
  });

  testWidgets('warns when the sender is not the account holder', (
    tester,
  ) async {
    stubOne(topup: testTopupReview(senderAccount: '01199999999'));
    await pump(tester);

    await open(tester);

    expect(find.text(l10n.adminTopupsDifferentSender), findsOneWidget);
  });

  testWidgets('approves after every check is ticked and confirmed', (
    tester,
  ) async {
    stubOne();
    when(
      () => h.topups.approve('topup-1'),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);
    await open(tester);

    FilledButton approve() => tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.adminTopupsApprove),
    );
    expect(approve().onPressed, isNull);

    await tickAll(tester);
    await tester.tap(find.text(l10n.adminTopupsApprove));
    await tester.pumpAndSettle();
    verifyNever(() => h.topups.approve(any()));

    await tester.tap(find.text(l10n.adminTopupsApproveConfirm));
    await tester.pumpAndSettle();

    verify(() => h.topups.approve('topup-1')).called(1);
    expect(find.text(l10n.adminTopupsApproved), findsOneWidget);
    // The reviewed transfer left the selection.
    expect(find.text(l10n.adminTopupsPickOne), findsOneWidget);
  });

  testWidgets('rejects with a reason that is long enough', (tester) async {
    stubOne();
    when(
      () => h.topups.reject(any(), any()),
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
      () => h.topups.reject('topup-1', l10n.adminTopupsReasonAmount),
    ).called(1);
    expect(find.text(l10n.adminTopupsRejected), findsOneWidget);
  });

  testWidgets('asks for a fresh sign in before moving money', (tester) async {
    stubOne();
    when(
      () => h.topups.approve(any()),
    ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure()));
    await pump(tester);
    await open(tester);
    await tickAll(tester);

    await tester.tap(find.text(l10n.adminTopupsApprove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminTopupsApproveConfirm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminReloginTitle), findsOneWidget);
  });

  testWidgets('approves again once the admin signed in anew', (tester) async {
    stubOne();
    var signedInAgain = false;
    when(() => h.topups.approve('topup-1')).thenAnswer(
      (_) async => signedInAgain
          ? const Ok(null)
          : const Err(RecentLoginRequiredFailure()),
    );
    when(
      () => h.auth.requestOtp(
        phone: any(named: 'phone'),
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => h.auth.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) async {
      signedInAgain = true;
      return const Ok(null);
    });
    await pump(tester);
    await open(tester);
    await tickAll(tester);
    await tester.tap(find.text(l10n.adminTopupsApprove));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminTopupsApproveConfirm));
    await tester.pumpAndSettle();

    // The code goes to the number of the signed-in admin, not to one typed.
    await tester.tap(find.text(l10n.phoneSendWhatsapp));
    await tester.pumpAndSettle();
    final sentTo =
        verify(
              () => h.auth.requestOtp(
                phone: captureAny(named: 'phone'),
                channel: OtpChannel.whatsapp,
              ),
            ).captured.single
            as PhoneNumber;
    expect(sentTo.e164, '+201001234567');

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pumpAndSettle();

    verify(() => h.topups.approve('topup-1')).called(2);
    expect(find.text(l10n.adminTopupsApproved), findsOneWidget);
  });

  testWidgets('shows the reason a transfer was rejected, as plain text', (
    tester,
  ) async {
    stubOne(
      topup: testTopupReview(
        status: TopupStatus.rejected,
        rejectReason: '<script>x</script>',
      ),
    );
    await pump(tester);
    await tester.tap(find.text(l10n.adminTopupsTabRejected));
    await tester.pumpAndSettle();

    await open(tester);

    expect(
      find.text(l10n.adminTopupsRejectedReason('<script>x</script>')),
      findsOneWidget,
    );
    expect(find.text(l10n.adminTopupsApprove), findsNothing);
  });
}
