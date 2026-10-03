import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/cubit/calendar_cubit.dart';

import '../../../../helpers/error_observer.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/job_list_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late Map<DateTime, StreamController<List<JobSummary>>> weeks;
  final now = DateTime(2026, 10, 2, 11);

  setUp(() {
    jobs = MockJobsRepository();
    weeks = {};
    when(
      () => jobs.watchScheduled(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).thenAnswer(
      (invocation) => weeks
          .putIfAbsent(
            invocation.namedArguments[#from] as DateTime,
            StreamController.broadcast,
          )
          .stream,
    );
  });

  CalendarCubit build({DateTime Function()? clock}) =>
      CalendarCubit(jobs: jobs, clock: clock ?? () => now)..start();

  JobSummary visit(String id, DateTime at) =>
      testSummary(listedJob(id: id, scheduledAt: at));

  test('opens on today with the seven days from today', () async {
    final cubit = build();

    expect(cubit.state.today, DateTime(2026, 10, 2));
    expect(cubit.state.selectedDay, DateTime(2026, 10, 2));
    expect(cubit.state.days.first, DateTime(2026, 10, 2));
    expect(cubit.state.days.last, DateTime(2026, 10, 8));
    verify(
      () => jobs.watchScheduled(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 9),
      ),
    ).called(1);
    expect(cubit.state.jobs, isNull);
    await cubit.close();
  });

  test("lays the day out hour by hour with the week's dots", () async {
    final cubit = build();
    final ten = visit('ten', DateTime(2026, 10, 2, 10));
    final halfPast = visit('half-past', DateTime(2026, 10, 2, 10, 30));
    final sunday = visit('sunday', DateTime(2026, 10, 4, 12));
    weeks[DateTime(2026, 10, 2)]!.add([ten, halfPast, sunday]);
    await pumpEventQueue();

    final slots = cubit.state.slots;
    expect(slots.first.hour, CalendarState.firstHour);
    expect(slots.last.hour, CalendarState.lastHour);
    expect(slots[1], CalendarSlot(10, [ten, halfPast]));
    expect(slots[0].jobs, isEmpty);
    expect(cubit.state.hasJobsOn(DateTime(2026, 10, 4)), isTrue);
    expect(cubit.state.hasJobsOn(DateTime(2026, 10, 3)), isFalse);
    await cubit.close();
  });

  test('widens the hours for visits outside them', () async {
    final cubit = build();
    weeks[DateTime(2026, 10, 2)]!.add([
      visit('early', DateTime(2026, 10, 2, 7, 30)),
      visit('late', DateTime(2026, 10, 2, 22)),
    ]);
    await pumpEventQueue();

    expect(cubit.state.slots.first.hour, 7);
    expect(cubit.state.slots.last.hour, 22);
    await cubit.close();
  });

  test('opens another day of the week', () async {
    final cubit = build();
    final sunday = visit('sunday', DateTime(2026, 10, 4, 12));
    weeks[DateTime(2026, 10, 2)]!.add([sunday]);
    await pumpEventQueue();

    cubit.selectDay(DateTime(2026, 10, 4, 15));

    expect(cubit.state.selectedDay, DateTime(2026, 10, 4));
    expect(cubit.state.week, 0);
    expect(cubit.state.slots.firstWhere((slot) => slot.hour == 12).jobs, [
      sunday,
    ]);
    verify(
      () => jobs.watchScheduled(
        from: any(named: 'from'),
        to: any(named: 'to'),
      ),
    ).called(1);
    await cubit.close();
  });

  test('moves a week on keeping the weekday, and back', () async {
    final cubit = build();
    weeks[DateTime(2026, 10, 2)]!.add([
      visit('today', DateTime(2026, 10, 2, 13)),
    ]);
    await pumpEventQueue();
    cubit
      ..selectDay(DateTime(2026, 10, 4))
      ..showWeek(1);

    expect(cubit.state.week, 1);
    expect(cubit.state.selectedDay, DateTime(2026, 10, 11));
    expect(cubit.state.days.first, DateTime(2026, 10, 9));
    expect(cubit.state.jobs, isNull);
    final next = visit('next', DateTime(2026, 10, 11, 10));
    weeks[DateTime(2026, 10, 9)]!.add([next]);
    await pumpEventQueue();
    expect(cubit.state.jobs, [next]);

    cubit.showWeek(-1);

    expect(cubit.state.selectedDay, DateTime(2026, 9, 27));
    verify(
      () => jobs.watchScheduled(
        from: DateTime(2026, 9, 25),
        to: DateTime(2026, 10, 2),
      ),
    ).called(1);
    await cubit.close();
  });

  test('ignores the week already shown', () async {
    final cubit = build();
    final before = cubit.state;

    cubit.showWeek(0);

    expect(cubit.state, before);
    await cubit.close();
  });

  test('stops following the week it left', () async {
    final cubit = build()..showWeek(1);

    weeks[DateTime(2026, 10, 2)]!.add([
      visit('old', DateTime(2026, 10, 2, 13)),
    ]);
    await pumpEventQueue();

    expect(cubit.state.jobs, isNull);
    await cubit.close();
  });

  test('comes back to today from any week', () async {
    final cubit = build()
      ..showWeek(3)
      ..showToday();

    expect(cubit.state.week, 0);
    expect(cubit.state.selectedDay, DateTime(2026, 10, 2));
    await cubit.close();
  });

  test('a day picked in another week moves the strip there', () async {
    final cubit = build()..selectDay(DateTime(2026, 9, 30));

    expect(cubit.state.week, -1);
    expect(cubit.state.weekStart, DateTime(2026, 9, 25));
    expect(cubit.state.selectedDay, DateTime(2026, 9, 30));
    await cubit.close();
  });

  test('moves today on after midnight', () {
    fakeAsync((async) {
      var clock = DateTime(2026, 10, 2, 23, 59);
      final cubit = build(clock: () => clock);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 1));
      expect(cubit.state.today, DateTime(2026, 10, 2));

      clock = DateTime(2026, 10, 3, 0, 1);
      async.elapse(const Duration(minutes: 1));

      expect(cubit.state.today, DateTime(2026, 10, 3));
      expect(cubit.state.origin, DateTime(2026, 10, 2));
      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test('reports stream errors', () async {
    final observer = ErrorObserver.install();
    final cubit = build();

    weeks[DateTime(2026, 10, 2)]!.addError(StateError('boom'));
    await pumpEventQueue();

    expect(observer.errors.single, isA<StateError>());
    expect(cubit.state.jobs, isNull);
    await cubit.close();
  });
}
