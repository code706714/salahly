import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/pages/overview_page.dart';

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

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const OverviewPage(),
    size: const Size(1440, 1400),
    settle: settle,
  );

  testWidgets('shows a spinner until the numbers arrive', (tester) async {
    final pending = Completer<Result<AdminOverview>>();
    when(
      () => h.overview.fetchOverview(any()),
    ).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows the numbers of the period', (tester) async {
    await pump(tester);

    expect(find.text(l10n.adminKpiVerified), findsWidgets);
    expect(find.text(l10n.adminFunnelTitle), findsOneWidget);
    expect(find.text(l10n.adminAttentionTitle), findsOneWidget);
    expect(find.text(l10n.adminCoverageTitle), findsOneWidget);
    expect(find.text('شبرا'), findsWidgets);
    expect(find.textContaining('76', findRichText: true), findsOneWidget);
    expect(find.text('142'), findsWidgets);
  });

  testWidgets('lists what waits for a decision and who rates low', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text(l10n.adminAttentionVerifications(12)), findsOneWidget);
    expect(find.text(l10n.adminAttentionComplaints(3)), findsOneWidget);
    expect(find.text(l10n.adminAttentionTopups(7)), findsOneWidget);
    expect(find.text(l10n.adminAttentionLowRated), findsOneWidget);
  });

  testWidgets('says all is well when nothing waits', (tester) async {
    when(() => h.overview.fetchOverview(any())).thenAnswer(
      (_) async => Ok(
        testOverview(
          pendingVerifications: 0,
          unanswered: 0,
          openComplaints: 0,
          pendingTopups: 0,
          lowRated: const [],
        ),
      ),
    );

    await pump(tester);

    expect(find.text(l10n.adminAttentionNothing), findsOneWidget);
  });

  testWidgets('says why the numbers did not load and tries again', (
    tester,
  ) async {
    when(
      () => h.overview.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pump(tester);
    expect(find.text(l10n.retry), findsOneWidget);

    when(
      () => h.overview.fetchOverview(any()),
    ).thenAnswer((_) async => Ok(testOverview()));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminKpiVerified), findsWidgets);
  });

  testWidgets('loads the period the admin picks', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.adminPeriodMonth));
    await tester.pumpAndSettle();

    verify(() => h.overview.fetchOverview(OverviewPeriod.month)).called(1);
  });
}
