import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';

import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  group('ScheduleChoice', () {
    const one = TimeOfDay(hour: 13, minute: 0);

    test('reads a visit back as its day and time', () {
      expect(ScheduleChoice.of(null), ScheduleChoice.none);
      final choice = ScheduleChoice.of(DateTime(2026, 10, 5, 13, 30));
      expect(choice.day, DateTime(2026, 10, 5));
      expect(choice.time, const TimeOfDay(hour: 13, minute: 30));
      expect(choice.scheduledAt, DateTime(2026, 10, 5, 13, 30));
    });

    test('is complete with both a day and a time, or neither', () {
      expect(ScheduleChoice.none.scheduledAt, isNull);
      expect(ScheduleChoice.none.needsTime, isFalse);
      final day = ScheduleChoice(day: DateTime(2026, 10, 5));
      expect(day.needsTime, isTrue);
      expect(day.scheduledAt, isNull);
    });

    test('a time with no day is for today', () {
      final choice = ScheduleChoice.none.withTime(
        one,
        today: DateTime(2026, 10, 2, 22),
      );

      expect(choice.scheduledAt, DateTime(2026, 10, 2, 13));
    });

    test('changing the day keeps the time, and the time can go', () {
      final choice = ScheduleChoice(
        day: DateTime(2026, 10, 2),
        time: one,
      ).withDay(DateTime(2026, 10, 4, 9));

      expect(choice.scheduledAt, DateTime(2026, 10, 4, 13));
      expect(choice.withoutTime(), ScheduleChoice(day: DateTime(2026, 10, 4)));
    });
  });

  group('SchedulePicker', () {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    late ScheduleChoice value;

    Future<void> pumpPicker(
      WidgetTester tester,
      ScheduleChoice initial, {
      bool showsErrors = false,
    }) {
      value = initial;
      return tester.pumpApp(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Padding(
              padding: const EdgeInsets.all(16),
              child: SchedulePicker(
                value: value,
                today: today,
                showsErrors: showsErrors,
                onChanged: (choice) => setState(() => value = choice),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('picks today and a usual time, and clears them', (
      tester,
    ) async {
      await pumpPicker(tester, ScheduleChoice.none);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.newJobTimeNoon));
      await tester.pump();
      expect(value.scheduledAt, day.add(const Duration(hours: 13)));

      await tester.tap(find.text(l10n.tomorrow));
      await tester.pump();
      expect(
        value.scheduledAt,
        DateTime(day.year, day.month, day.day + 1, 13),
      );

      await tester.tap(find.text(l10n.newJobTimeNoon));
      await tester.pump();
      expect(value.needsTime, isTrue);

      await tester.tap(find.text(l10n.tomorrow));
      await tester.pump();
      expect(value, ScheduleChoice.none);
    });

    testWidgets('says the time is missing once asked to', (tester) async {
      await pumpPicker(tester, ScheduleChoice(day: day), showsErrors: true);

      expect(find.text(l10n.newJobTimeRequired), findsOneWidget);

      await tester.tap(find.text(l10n.newJobTimeEvening));
      await tester.pump();

      expect(find.text(l10n.newJobTimeRequired), findsNothing);
    });

    testWidgets('picks another day from the calendar', (tester) async {
      await pumpPicker(tester, ScheduleChoice.none);

      await tester.tap(find.text(l10n.newJobOtherDay));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(DatePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(context).okButtonLabel),
      );
      await tester.pumpAndSettle();

      final picked = DateTime(day.year, day.month, day.day + 2);
      expect(value.day, picked);
      expect(find.text(weekdayDate(picked)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('picks another time from the clock', (tester) async {
      await pumpPicker(
        tester,
        ScheduleChoice(day: day, time: const TimeOfDay(hour: 17, minute: 30)),
      );
      expect(
        find.text(
          timeLabel(l10n, day.add(const Duration(hours: 17, minutes: 30))),
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.text(
          timeLabel(l10n, day.add(const Duration(hours: 17, minutes: 30))),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TimePickerDialog));
      await tester.tap(
        find.text(MaterialLocalizations.of(context).okButtonLabel),
      );
      await tester.pumpAndSettle();

      expect(value.time, const TimeOfDay(hour: 17, minute: 30));
    });

    testWidgets('leaves the choice alone when a picker is dismissed', (
      tester,
    ) async {
      await pumpPicker(tester, ScheduleChoice.none);

      final context = tester.element(find.byType(SchedulePicker));
      await tester.tap(find.text(l10n.newJobOtherDay));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(MaterialLocalizations.of(context).cancelButtonLabel),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.newJobOtherTime));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(MaterialLocalizations.of(context).cancelButtonLabel),
      );
      await tester.pumpAndSettle();

      expect(value, ScheduleChoice.none);
    });
  });

  group('showSchedulePicker', () {
    late ScheduleChoice? result;
    late bool closed;

    Future<void> open(WidgetTester tester, {DateTime? initial}) async {
      closed = false;
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showSchedulePicker(context, initial: initial);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('returns the new date', (tester) async {
      final today = DateTime.now();
      await open(tester, initial: today);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.tomorrow));
      await tester.pump();
      await tester.tap(find.text(l10n.newJobTimeMorning));
      await tester.pump();
      await tester.tap(find.text(l10n.newJobScheduleDone));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(
        result?.scheduledAt,
        DateTime(today.year, today.month, today.day + 1, 10),
      );
    });

    testWidgets('asks for the time before closing', (tester) async {
      await open(tester);

      await tester.tap(find.text(l10n.today));
      await tester.pump();
      await tester.tap(find.text(l10n.newJobScheduleDone));
      await tester.pumpAndSettle();

      expect(closed, isFalse);
      expect(find.text(l10n.newJobTimeRequired), findsOneWidget);
    });

    testWidgets('can say there is no date yet', (tester) async {
      await open(tester, initial: DateTime.now());

      await tester.tap(find.text(l10n.newJobNoDate));
      await tester.pumpAndSettle();

      expect(result, ScheduleChoice.none);
    });

    testWidgets('returns nothing when dismissed', (tester) async {
      await open(tester);

      await tester.tapAt(const Offset(180, 20));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
