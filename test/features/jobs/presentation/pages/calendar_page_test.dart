import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/cubit/calendar_cubit.dart';
import 'package:salahly/features/jobs/presentation/pages/calendar_page.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/new_job_page.dart';
import 'package:salahly/features/jobs/presentation/widgets/calendar_day_schedule.dart';
import 'package:salahly/features/jobs/presentation/widgets/calendar_week_strip.dart';

import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/job_list_fixtures.dart';
import '../../../../helpers/job_seed.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockCalendarCubit extends MockCubit<CalendarState>
    implements CalendarCubit {}

void main() {
  late _MockCalendarCubit cubit;
  final today = DateTime(2026, 10, 2);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
  });

  setUp(() => cubit = _MockCalendarCubit());

  final hala = testSummary(
    listedJob(
      tags: const [JobTag.cleaning, JobTag.freon],
      scheduledAt: DateTime(2026, 10, 2, 10),
      durationMinutes: 90,
    ),
    customerName: 'أ. هالة فتحي',
  );
  final nadia = testSummary(
    listedJob(
      id: 'nadia',
      tags: const [],
      description: 'بيفصل لوحده',
      status: JobStatus.unconfirmed,
      scheduledAt: DateTime(2026, 10, 2, 16, 30),
    ),
    customerName: 'مدام نادية سمير',
  );
  final nourhan = testSummary(
    listedJob(
      id: 'nourhan',
      tags: const [JobTag.notCooling],
      scheduledAt: DateTime(2026, 10, 2, 12),
      source: JobSource.platform,
    ),
    customerName: 'نورهان م.',
  );
  final done = testSummary(
    listedJob(
      id: 'done',
      status: JobStatus.paid,
      scheduledAt: DateTime(2026, 10, 2, 19),
      durationMinutes: 180,
    ),
    customerName: 'دعاء م.',
  );
  final sunday = testSummary(
    listedJob(id: 'sunday', scheduledAt: DateTime(2026, 10, 4, 10)),
  );

  CalendarState stateOn(DateTime day, {int week = 0}) => CalendarState(
    origin: today,
    today: today,
    week: week,
    selectedDay: day,
    jobs: [hala, nourhan, nadia, done, sunday],
  );

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    const CalendarView(),
    blocs: [BlocProvider<CalendarCubit>.value(value: cubit)],
    stubRoutes: [AppRoutes.newJob, AppRoutes.job('job-1')],
  );

  testWidgets("shows the week and the day's visits hour by hour", (
    tester,
  ) async {
    when(() => cubit.state).thenReturn(stateOn(today));
    await pumpView(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.calendarTitle('أكتوبر')), findsOneWidget);
    expect(find.text(l10n.calendarFriday), findsOneWidget);
    expect(find.text(l10n.calendarThursday), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(
      find.text('${weekdayDate(today)} · ${l10n.today}'),
      findsOneWidget,
    );
    expect(find.text(l10n.calendarHourMorning(9)), findsOneWidget);
    expect(find.text(l10n.calendarHourNoon(12)), findsOneWidget);
    expect(find.text('أ. هالة فتحي'), findsOneWidget);
    expect(
      find.text(
        '${l10n.jobTagCleaning} + ${l10n.jobTagFreon} · '
        '${l10n.calendarHoursAndHalf(1)}',
      ),
      findsOneWidget,
    );
    expect(
      find.text('نورهان م. · ${l10n.jobFromPlatform}'),
      findsOneWidget,
    );
    expect(find.text(l10n.newJob), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('دعاء م.'),
      200,
      scrollable: _schedule,
    );
    expect(
      find.text('4:30 · بيفصل لوحده · ${l10n.calendarHours(1)}'),
      findsOneWidget,
    );
    expect(find.text(l10n.calendarHourEvening(8)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('says the day is tomorrow, or only its date', (tester) async {
    when(() => cubit.state).thenReturn(stateOn(DateTime(2026, 10, 3)));
    await pumpView(tester);
    expect(
      find.text('${weekdayDate(DateTime(2026, 10, 3))} · ${l10n.tomorrow}'),
      findsOneWidget,
    );

    when(() => cubit.state).thenReturn(stateOn(DateTime(2026, 10, 5)));
    await pumpView(tester);
    expect(find.text(weekdayDate(DateTime(2026, 10, 5))), findsOneWidget);
  });

  testWidgets('names the year of a month in another year', (tester) async {
    final january = DateTime(2027, 1, 4);
    when(() => cubit.state).thenReturn(
      CalendarState(
        origin: today,
        today: today,
        week: 13,
        selectedDay: january,
        jobs: const [],
      ),
    );
    await pumpView(tester);

    expect(find.text(l10n.calendarTitle('يناير 2027')), findsOneWidget);
  });

  testWidgets('opens a day, today and other weeks', (tester) async {
    when(() => cubit.state).thenReturn(stateOn(today));
    await pumpView(tester);

    await tester.tap(find.text('4'));
    verify(() => cubit.selectDay(DateTime(2026, 10, 4))).called(1);

    await tester.tap(find.text(l10n.today).first);
    verify(() => cubit.showToday()).called(1);

    await tester.fling(
      find.byType(CalendarWeekStrip),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();
    verify(() => cubit.showWeek(1)).called(1);
  });

  testWidgets('opens a visit', (tester) async {
    when(() => cubit.state).thenReturn(stateOn(today));
    await pumpView(tester);

    await tester.tap(find.text('أ. هالة فتحي'));
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.job('job-1')), findsOneWidget);
  });

  testWidgets('an empty hour starts a new job', (tester) async {
    when(() => cubit.state).thenReturn(stateOn(today));
    await pumpView(tester);

    await tester.tap(
      find.bySemanticsLabel(
        l10n.calendarNewJobAt(timeLabel(l10n, DateTime(2026, 10, 2, 9))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(AppRoutes.newJob), findsOneWidget);
  });

  testWidgets('shows no hours until the week loads', (tester) async {
    when(() => cubit.state).thenReturn(
      CalendarState(origin: today, today: today, selectedDay: today),
    );
    await pumpView(tester);

    expect(find.byType(CalendarDaySchedule), findsNothing);
  });

  test('names hours by the part of the day', () {
    expect(
      [9, 12, 13, 16, 18, 20, 2].map((hour) => hourLabel(l10n, hour)),
      ['9 ص', '12 ض', '1 ض', '4 ع', '6 م', '8 م', '2 ص'],
    );
  });

  test('says how long a visit takes', () {
    expect(
      [30, 45, 60, 90, 120, 150, 180, 240, 75].map(
        (minutes) => visitLength(l10n, minutes),
      ),
      [
        'نص ساعة',
        '45 دقيقة',
        'ساعة',
        'ساعة ونص',
        'ساعتين',
        'ساعتين ونص',
        '3 ساعات',
        '4 ساعات',
        'ساعة و15 دقيقة',
      ],
    );
  });

  testTechnicianApp('the calendar opens visits and books empty hours', (
    tester,
    app,
  ) async {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    late String jobId;
    await tester.runAsync(() async {
      final sherif = await seedCustomer(app, 'م. شريف عادل');
      jobId = await seedJob(
        app,
        sherif,
        tags: const [JobTag.installation],
        at: tomorrow.add(const Duration(hours: 13)),
      );
    });
    await app.pump(tester, location: AppRoutes.technicianJobs);
    await tester.tap(find.byTooltip(l10n.jobsListCalendar));
    await app.settle(tester);

    expect(find.byType(CalendarPage), findsOneWidget);
    expect(find.text('م. شريف عادل'), findsNothing);

    await tester.tap(find.text(weekdayShortName(l10n, tomorrow)));
    await app.settle(tester);
    expect(find.text('م. شريف عادل'), findsOneWidget);

    await tester.tap(find.text('م. شريف عادل'));
    await app.settle(tester);
    expect(tester.widget<JobPage>(find.byType(JobPage)).jobId, jobId);

    app.router(tester).pop();
    await app.settle(tester);
    final four = find.bySemanticsLabel(
      l10n.calendarNewJobAt(
        timeLabel(l10n, tomorrow.add(const Duration(hours: 16))),
      ),
    );
    await tester.scrollUntilVisible(four, 200, scrollable: _schedule);
    // Clear of the new job button floating over the bottom.
    await tester.drag(_schedule, const Offset(0, -150));
    await app.settle(tester);
    await tester.tap(four);
    await app.settle(tester);

    final page = tester.widget<NewJobPage>(find.byType(NewJobPage));
    expect(page.scheduledAt, tomorrow.add(const Duration(hours: 16)));
    await tester.scrollUntilVisible(
      find.text(l10n.newJobOtherTime),
      200,
      scrollable: find
          .descendant(
            of: find.byType(NewJobView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final chosen = tester
        .widgetList<ChoiceChipButton>(find.byType(ChoiceChipButton))
        .where((chip) => chip.selected)
        .map((chip) => chip.label);
    expect(chosen, [l10n.tomorrow, l10n.newJobTimeAfternoon]);
  });
}

/// The day's hours, as opposed to the strip of days.
final Finder _schedule = find.descendant(
  of: find.byType(ListView),
  matching: find.byType(Scrollable),
);
