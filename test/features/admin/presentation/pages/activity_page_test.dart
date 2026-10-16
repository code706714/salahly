import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/pages/activity_page.dart';

import '../../../../helpers/activity_fixtures.dart';
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
      () => h.activity.fetchMoney(any()),
    ).thenAnswer((_) async => Ok(testMoney()));
    when(
      () => h.activity.fetchTechnicians(any()),
    ).thenAnswer((_) async => Ok(testActivityReport()));
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const ActivityPage(),
    size: const Size(1440, 1400),
    settle: settle,
  );

  testWidgets('shows a spinner until the numbers arrive', (tester) async {
    final pending = Completer<Result<MoneySummary>>();
    when(() => h.activity.fetchMoney(any())).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows what we earned and the money that moved', (tester) async {
    await pump(tester);

    expect(find.text(l10n.adminActivityEarned), findsOneWidget);
    expect(find.text(l10n.pounds('150')), findsWidgets);
    expect(find.text(l10n.adminActivityKindPack), findsOneWidget);
    expect(find.text('كريم'), findsWidgets);
  });

  testWidgets('opens a technician to see their customers', (tester) async {
    await pump(tester);

    expect(find.text('منى'), findsNothing);
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    expect(find.text('منى'), findsOneWidget);
    expect(find.text(l10n.adminActivityJobFromApp), findsOneWidget);
  });

  testWidgets('says so when no technician worked', (tester) async {
    when(() => h.activity.fetchTechnicians(any())).thenAnswer(
      (_) async => const Ok(
        ActivityReport(
          techniciansActive: 0,
          jobsCount: 0,
          finishedCount: 0,
          billedPiastres: 0,
          technicians: [],
        ),
      ),
    );

    await pump(tester);

    expect(find.text(l10n.adminActivityTechniciansEmpty), findsOneWidget);
  });

  testWidgets('says why the numbers did not load and tries again', (
    tester,
  ) async {
    when(
      () => h.activity.fetchMoney(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pump(tester);
    expect(find.text(l10n.retry), findsOneWidget);

    when(
      () => h.activity.fetchMoney(any()),
    ).thenAnswer((_) async => Ok(testMoney()));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminActivityEarned), findsOneWidget);
  });

  testWidgets('loads the period the admin picks', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.adminPeriodMonth));
    await tester.pumpAndSettle();

    verify(() => h.activity.fetchMoney(OverviewPeriod.month)).called(1);
  });
}
