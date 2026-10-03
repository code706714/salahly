import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';

part 'calendar_state.dart';

/// The schedule a week at a time, starting today, with one day open hour
/// by hour.
///
/// Checks the clock every minute so "today" moves on past midnight.
class CalendarCubit extends Cubit<CalendarState> {
  CalendarCubit({
    required this._jobs,
    this._clock = DateTime.now,
    this._tick = const Duration(minutes: 1),
  }) : super(_opening(_clock()));

  final JobsRepository _jobs;
  final DateTime Function() _clock;
  final Duration _tick;

  StreamSubscription<List<JobSummary>>? _week;
  Timer? _ticker;

  static CalendarState _opening(DateTime now) {
    final today = CalendarDate.of(now);
    return CalendarState(origin: today, today: today, selectedDay: today);
  }

  void start() {
    _watchWeek();
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  /// Opens [day], moving the strip to its week when needed.
  void selectDay(DateTime day) {
    final selected = CalendarDate.of(day);
    final week = state.weekOf(selected);
    if (week == state.week) {
      emit(_copy(selectedDay: selected));
      return;
    }
    emit(_copy(week: week, selectedDay: selected, clearJobs: true));
    _watchWeek();
  }

  /// Moves the strip to [week], keeping the same weekday open.
  void showWeek(int week) {
    if (week == state.week) return;
    final selected = state.selectedDay;
    final shift = 7 * (week - state.week);
    emit(
      _copy(
        week: week,
        selectedDay: DateTime(
          selected.year,
          selected.month,
          selected.day + shift,
        ),
        clearJobs: true,
      ),
    );
    _watchWeek();
  }

  void showToday() => selectDay(state.today);

  void _onTick() {
    final today = CalendarDate.of(_clock());
    if (today != state.today) emit(_copy(today: today));
  }

  void _watchWeek() {
    final start = state.weekStart;
    unawaited(_week?.cancel());
    _week = _jobs
        .watchScheduled(
          from: start,
          to: DateTime(start.year, start.month, start.day + 7),
        )
        .listen(
          (jobs) => emit(_copy(jobs: jobs)),
          onError: addError,
        );
  }

  CalendarState _copy({
    DateTime? today,
    int? week,
    DateTime? selectedDay,
    List<JobSummary>? jobs,
    bool clearJobs = false,
  }) => CalendarState(
    origin: state.origin,
    today: today ?? state.today,
    week: week ?? state.week,
    selectedDay: selectedDay ?? state.selectedDay,
    jobs: clearJobs ? null : jobs ?? state.jobs,
  );

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _week?.cancel();
    return super.close();
  }
}
