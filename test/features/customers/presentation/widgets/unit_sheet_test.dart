import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/widgets/unit_sheet.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  final today = DateTime(2026, 10, 2);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  /// Opens the sheet over a blank screen. The returned list gets what the
  /// sheet closed with.
  Future<List<UnitSheetResult?>> open(
    WidgetTester tester, {
    CustomerUnit? unit,
  }) async {
    final results = <UnitSheetResult?>[];
    await tester.pumpApp(
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await showUnitSheet(context, today: today, unit: unit),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Finder field(int index) => find.byType(TextField).at(index);

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text(l10n.unitSave));
    await tester.tap(find.text(l10n.unitSave));
    await tester.pumpAndSettle();
  }

  group('a new unit', () {
    testWidgets('asks for its details', (tester) async {
      await open(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.unitAddTitle), findsOneWidget);
      for (final hp in ['1', '1.5', '2.25', '3', '4', '5']) {
        expect(find.text(l10n.unitHp(hp)), findsOneWidget);
      }
      expect(find.text(l10n.unitNoNextService), findsOneWidget);
      expect(find.text(l10n.unitPickDay), findsOneWidget);
      expect(find.text(l10n.unitDelete), findsNothing);
    });

    testWidgets('saves what was typed and picked', (tester) async {
      final results = await open(tester);

      await tester.enterText(field(0), '  شارب ');
      await tester.tap(find.text(l10n.unitHp('1.5')));
      await tester.enterText(field(1), 'أوضة النوم');
      await tester.enterText(field(2), '2021');
      await tester.ensureVisible(find.text(l10n.unitInSixMonths));
      await tester.tap(find.text(l10n.unitInSixMonths));
      await tester.pump();
      await save(tester);

      expect(results, [
        isA<UnitSaved>().having(
          (result) => result.draft,
          'draft',
          CustomerUnitDraft(
            brand: 'شارب',
            capacityHp: 1.5,
            room: 'أوضة النوم',
            installedYear: 2021,
            nextServiceOn: DateTime(2027, 4, 2),
          ),
        ),
      ]);
    });

    testWidgets('can be saved with nothing known yet', (tester) async {
      final results = await open(tester);

      await save(tester);

      expect(results, [
        isA<UnitSaved>().having(
          (result) => result.draft,
          'draft',
          const CustomerUnitDraft(),
        ),
      ]);
    });

    testWidgets('cleans in a year', (tester) async {
      final results = await open(tester);

      await tester.ensureVisible(find.text(l10n.unitInAYear));
      await tester.tap(find.text(l10n.unitInAYear));
      await tester.pump();
      await save(tester);

      expect(
        (results.single! as UnitSaved).draft.nextServiceOn,
        DateTime(2027, 10, 2),
      );
    });

    testWidgets('refuses a year that cannot be', (tester) async {
      final results = await open(tester);

      await tester.enterText(field(2), '1975');
      await save(tester);

      expect(results, isEmpty);
      expect(find.text(l10n.unitInstalledYearInvalid(1980, 2026)), findsOne);
      expect(tester.takeException(), isNull);

      await tester.enterText(field(2), '2026');
      await tester.pump();
      expect(
        find.text(l10n.unitInstalledYearInvalid(1980, 2026)),
        findsNothing,
      );
    });

    testWidgets('cleans on a day picked from the calendar', (tester) async {
      final results = await open(tester);

      await tester.ensureVisible(find.text(l10n.unitPickDay));
      await tester.tap(find.text(l10n.unitPickDay));
      await tester.pumpAndSettle();
      final material = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      );
      await tester.tap(find.text(material.formatDecimal(15)));
      await tester.tap(find.text(material.okButtonLabel));
      await tester.pumpAndSettle();

      expect(find.text('15 أبريل'), findsOneWidget);
      expect(find.text(l10n.unitPickDay), findsNothing);

      await save(tester);
      expect(
        (results.single! as UnitSaved).draft.nextServiceOn,
        DateTime(2027, 4, 15),
      );
    });

    testWidgets('closes with nothing when dismissed', (tester) async {
      final results = await open(tester);

      Navigator.of(tester.element(find.text(l10n.unitAddTitle))).pop();
      await tester.pumpAndSettle();

      expect(results, [null]);
    });
  });

  group('a saved unit', () {
    final unit = testUnit(nextServiceOn: DateTime(2027, 3));

    testWidgets('shows what is known about it', (tester) async {
      await open(tester, unit: unit);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.unitEditTitle), findsOneWidget);
      expect(find.text('شارب'), findsOneWidget);
      expect(find.text('الصالة'), findsOneWidget);
      expect(find.text('2021'), findsOneWidget);
      expect(find.text('أول مارس'), findsOneWidget);
      expect(find.text(l10n.unitDelete), findsOneWidget);
    });

    testWidgets('forgets the capacity when its chip is tapped again', (
      tester,
    ) async {
      final results = await open(tester, unit: unit);

      await tester.tap(find.text(l10n.unitHp('1.5')));
      await tester.pump();
      await save(tester);

      expect(results, [
        isA<UnitSaved>().having(
          (result) => result.draft,
          'draft',
          CustomerUnitDraft(
            brand: 'شارب',
            room: 'الصالة',
            installedYear: 2021,
            nextServiceOn: DateTime(2027, 3),
          ),
        ),
      ]);
    });

    testWidgets('keeps a capacity the chips do not offer', (tester) async {
      final results = await open(tester, unit: testUnit(capacityHp: 2.5));

      expect(find.text(l10n.unitHp('2.5')), findsOneWidget);
      await save(tester);

      expect((results.single! as UnitSaved).draft.capacityHp, 2.5);
    });

    testWidgets('stops being cleaned on a set day', (tester) async {
      final results = await open(tester, unit: unit);

      await tester.ensureVisible(find.text(l10n.unitNoNextService));
      await tester.tap(find.text(l10n.unitNoNextService));
      await tester.pump();
      await save(tester);

      expect((results.single! as UnitSaved).draft.nextServiceOn, isNull);
    });

    testWidgets('asks to be deleted', (tester) async {
      final results = await open(tester, unit: unit);

      await tester.ensureVisible(find.text(l10n.unitDelete));
      await tester.tap(find.text(l10n.unitDelete));
      await tester.pumpAndSettle();

      expect(results, [isA<UnitDeleteRequested>()]);
    });
  });
}
