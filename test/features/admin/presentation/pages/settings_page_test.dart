import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/pages/settings_page.dart';
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
      () => h.settings.fetchSettings(),
    ).thenAnswer((_) async => Ok(testSettings()));
    when(
      () => h.settings.updateFreeUses(
        consumerFreeRequests: any(named: 'consumerFreeRequests'),
        technicianFreeJobs: any(named: 'technicianFreeJobs'),
        verifiedTechnicianTarget: any(named: 'verifiedTechnicianTarget'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => h.settings.saveCreditPack(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => h.settings.updatePaymentAccount(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => h.settings.saveArea(any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => h.settings.setAreaOpen(any(), isOpen: any(named: 'isOpen')),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const SettingsPage(),
    path: AdminRoutes.settings,
    size: const Size(1440, 1800),
    settle: settle,
  );

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  // The price fields of the page are text fields too.
  final dialogFields = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  Finder saveButton() =>
      find.widgetWithText(FilledButton, l10n.adminSettingsSave);

  Future<void> changeConsumerPrice(WidgetTester tester, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, '80'), text);
    await tester.pump();
  }

  Future<void> confirmSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    await tester.tap(inDialog(l10n.adminSettingsSaveConfirm));
    await tester.pumpAndSettle();
  }

  testWidgets('shows a spinner while the settings load', (tester) async {
    final pending = Completer<Result<AdminSettings>>();
    when(() => h.settings.fetchSettings()).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says why the settings did not load and tries again', (
    tester,
  ) async {
    when(
      () => h.settings.fetchSettings(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pump(tester);

    when(
      () => h.settings.fetchSettings(),
    ).thenAnswer((_) async => Ok(testSettings()));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminSettingsConsumerPacks), findsOneWidget);
  });

  testWidgets('shows the packs, the accounts and the areas', (tester) async {
    await pump(tester);

    expect(find.text(l10n.adminSettingsConsumerPacks), findsOneWidget);
    expect(find.text(l10n.adminSettingsTechnicianPacks), findsOneWidget);
    expect(find.text(l10n.adminSettingsAccountsTitle), findsOneWidget);
    expect(find.text('مدينة نصر · القاهرة'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '80'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
  });

  testWidgets('keeps save off until something changed', (tester) async {
    await pump(tester);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);

    await changeConsumerPrice(tester, '90');

    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNotNull);
  });

  testWidgets('keeps save off for a price the server would refuse', (
    tester,
  ) async {
    await pump(tester);

    await changeConsumerPrice(tester, '0');

    expect(find.text(l10n.adminSettingsPackPriceInvalid), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton()).onPressed, isNull);
  });

  testWidgets('saves a changed price after the admin confirms', (tester) async {
    await pump(tester);
    await changeConsumerPrice(tester, '90');

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    verifyNever(() => h.settings.saveCreditPack(any()));

    await tester.tap(inDialog(l10n.adminSettingsSaveConfirm));
    await tester.pumpAndSettle();

    final saved =
        verify(() => h.settings.saveCreditPack(captureAny())).captured.single
            as CreditPackDraft;
    expect(saved.id, 'pack-c5');
    expect(saved.role, UserRole.consumer);
    expect(saved.pricePiastres, 9000);
    verifyNever(
      () => h.settings.updateFreeUses(
        consumerFreeRequests: any(named: 'consumerFreeRequests'),
        technicianFreeJobs: any(named: 'technicianFreeJobs'),
        verifiedTechnicianTarget: any(named: 'verifiedTechnicianTarget'),
      ),
    );
    expect(find.text(l10n.adminSettingsSaved), findsOneWidget);
    // The settings were read again after the save.
    verify(() => h.settings.fetchSettings()).called(2);
  });

  testWidgets('does not save when the admin cancels', (tester) async {
    await pump(tester);
    await changeConsumerPrice(tester, '90');

    await tester.tap(saveButton());
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminCancel));
    await tester.pumpAndSettle();

    verifyNever(() => h.settings.saveCreditPack(any()));
  });

  testWidgets('saves a changed number of free uses', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip(l10n.adminSettingsMore).first);
    await tester.pump();
    await confirmSave(tester);

    verify(
      () => h.settings.updateFreeUses(
        consumerFreeRequests: 4,
        technicianFreeJobs: 5,
        verifiedTechnicianTarget: 100,
      ),
    ).called(1);
  });

  testWidgets('asks for a fresh sign in before changing prices', (
    tester,
  ) async {
    when(
      () => h.settings.saveCreditPack(any()),
    ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure()));
    await pump(tester);
    await changeConsumerPrice(tester, '90');

    await confirmSave(tester);

    expect(find.text(l10n.adminReloginTitle), findsOneWidget);
  });

  testWidgets('says why the server refused a change', (tester) async {
    when(
      () => h.settings.saveCreditPack(any()),
    ).thenAnswer((_) async => const Err(LastActiveFailure()));
    await pump(tester);
    await changeConsumerPrice(tester, '90');

    await confirmSave(tester);

    expect(find.text(l10n.adminErrorLastActive), findsOneWidget);
  });

  testWidgets('opens a closed area only after the admin confirms', (
    tester,
  ) async {
    await pump(tester);

    // The areas come last, and the last one is closed.
    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();
    verifyNever(
      () => h.settings.setAreaOpen(any(), isOpen: any(named: 'isOpen')),
    );
    expect(
      find.text(l10n.adminSettingsAreaOpenTitle('عين شمس')),
      findsOneWidget,
    );

    await tester.tap(inDialog(l10n.adminSettingsAreaOpenConfirm));
    await tester.pumpAndSettle();

    verify(() => h.settings.setAreaOpen('ain_shams', isOpen: true)).called(1);
  });

  testWidgets('adds a pack from its dialog', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.adminSettingsAddPack).first);
    await tester.pumpAndSettle();
    final add = find.ancestor(
      of: inDialog(l10n.adminSettingsPackAdd),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(add).onPressed, isNull);

    await tester.enterText(dialogFields.first, '20');
    await tester.enterText(dialogFields.last, '120');
    await tester.pump();
    await tester.tap(add);
    await tester.pumpAndSettle();

    final saved =
        verify(() => h.settings.saveCreditPack(captureAny())).captured.single
            as CreditPackDraft;
    expect(saved.id, isNull);
    expect(saved.role, UserRole.consumer);
    expect(saved.uses, 20);
    expect(saved.pricePiastres, 12000);
    expect(find.text(l10n.adminSettingsPackSaved), findsOneWidget);
  });

  testWidgets('does not offer to add a pack over unsaved changes', (
    tester,
  ) async {
    await pump(tester);

    await changeConsumerPrice(tester, '90');

    final add = find.widgetWithText(TextButton, l10n.adminSettingsAddPack);
    for (final button in add.evaluate()) {
      expect((button.widget as TextButton).onPressed, isNull);
    }
  });

  testWidgets('refuses an area id that exists', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.adminSettingsAddArea));
    await tester.pumpAndSettle();
    final fields = dialogFields;
    await tester.enterText(fields.at(0), 'shubra');
    await tester.enterText(fields.at(1), 'شبرا');
    await tester.enterText(fields.at(2), 'القاهرة');
    await tester.enterText(fields.at(3), '30.1');
    await tester.enterText(fields.at(4), '31.2');
    await tester.pump();

    final add = find.ancestor(
      of: inDialog(l10n.adminSettingsAreaAdd),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(add).onPressed, isNull);

    await tester.enterText(fields.at(0), 'new_cairo');
    await tester.pump();
    expect(tester.widget<TextButton>(add).onPressed, isNotNull);

    await tester.tap(add);
    await tester.pumpAndSettle();

    final saved =
        verify(() => h.settings.saveArea(captureAny())).captured.single
            as AreaDraft;
    expect(saved.id, 'new_cairo');
    expect(saved.centerLat, 30.1);
  });

  testWidgets('says so when an area with that id exists on the server', (
    tester,
  ) async {
    when(
      () => h.settings.saveArea(any()),
    ).thenAnswer((_) async => const Err(DuplicateFailure()));
    await pump(tester);

    await tester.tap(find.text(l10n.adminSettingsAddArea));
    await tester.pumpAndSettle();
    final fields = dialogFields;
    await tester.enterText(fields.at(0), 'new_cairo');
    await tester.enterText(fields.at(1), 'القاهرة الجديدة');
    await tester.enterText(fields.at(2), 'القاهرة');
    await tester.enterText(fields.at(3), '30.1');
    await tester.enterText(fields.at(4), '31.2');
    await tester.pump();
    await tester.tap(inDialog(l10n.adminSettingsAreaAdd));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminErrorDuplicate), findsOneWidget);
  });
}
