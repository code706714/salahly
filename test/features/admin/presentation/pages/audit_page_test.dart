import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/presentation/pages/audit_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';

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

  setUp(() => h = AdminHarness());

  void stubLog(Result<PagedResult<AuditEntry>> result) => when(
    () => h.audit.fetchLog(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const AuditPage(),
    path: AdminRoutes.audit,
    size: const Size(1440, 1400),
    settle: settle,
  );

  testWidgets('shows a spinner while the log loads', (tester) async {
    final pending = Completer<Result<PagedResult<AuditEntry>>>();
    when(
      () => h.audit.fetchLog(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says so when the filter matches nothing', (tester) async {
    stubLog(const Ok(PagedResult(items: [], total: 0)));

    await pump(tester);

    expect(find.text(l10n.adminAuditEmpty), findsOneWidget);
  });

  testWidgets('says why the log did not load and tries again', (tester) async {
    stubLog(const Err(NetworkFailure()));
    await pump(tester);

    stubLog(Ok(PagedResult(items: [testAuditEntry()], total: 1)));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminAuditApproveTopup), findsWidgets);
  });

  testWidgets('shows who did what, with the details as plain text', (
    tester,
  ) async {
    stubLog(
      Ok(
        PagedResult(
          items: [
            testAuditEntry(details: const {'reason': '<b>تمام</b>'}),
            testAuditEntry(id: 2, adminName: null, details: const {}),
          ],
          total: 2,
        ),
      ),
    );

    await pump(tester);

    expect(find.text('أحمد'), findsOneWidget);
    expect(find.text(l10n.adminAuditUnknownAdmin), findsOneWidget);
    expect(find.text('reason: <b>تمام</b>'), findsOneWidget);
    expect(find.text('topup · topup-1'), findsNWidgets(2));
  });

  testWidgets('narrows the log by the id of what was acted on', (
    tester,
  ) async {
    stubLog(Ok(PagedResult(items: [testAuditEntry()], total: 1)));
    await pump(tester);

    await tester.enterText(find.byType(TextField).first, ' topup-1 ');
    await tester.pump(AdminSearchField.debounce);
    await tester.pumpAndSettle();

    verify(
      () => h.audit.fetchLog(
        const AuditFilter(targetId: 'topup-1'),
        limit: any(named: 'limit'),
        offset: 0,
      ),
    ).called(1);
  });

  testWidgets('goes to the next page', (tester) async {
    stubLog(
      Ok(
        PagedResult(
          items: [for (var i = 1; i <= 25; i++) testAuditEntry(id: i)],
          total: 60,
        ),
      ),
    );
    await pump(tester);

    await tester.ensureVisible(find.text(l10n.adminNextPage));
    await tester.tap(find.text(l10n.adminNextPage));
    await tester.pumpAndSettle();

    verify(
      () => h.audit.fetchLog(
        any(),
        limit: 25,
        offset: 25,
      ),
    ).called(1);
  });
}
