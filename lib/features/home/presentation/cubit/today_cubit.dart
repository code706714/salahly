import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';

part 'today_state.dart';

/// The day at a glance: today's visits and the money still out.
///
/// Ticks every minute so the highlighted visit moves on with the clock,
/// and follows the next day's visits after midnight.
class TodayCubit extends Cubit<TodayState> {
  TodayCubit({
    required this._jobs,
    this._clock = DateTime.now,
    this._tick = const Duration(minutes: 1),
  }) : super(TodayState(now: _clock()));

  final JobsRepository _jobs;
  final DateTime Function() _clock;
  final Duration _tick;

  StreamSubscription<List<JobSummary>>? _schedule;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _ticker;

  void start() {
    _watchDay(state.now);
    _subscriptions
      ..add(
        _jobs.watchAwaitingPayment().listen(
          (jobs) => emit(state.copyWith(awaitingPayment: jobs)),
          onError: addError,
        ),
      )
      ..add(
        _jobs.watchHasJobs().listen(
          (hasJobs) => emit(state.copyWith(hasJobs: hasJobs)),
          onError: addError,
        ),
      );
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void _onTick() {
    final now = _clock();
    if (CalendarDate.daysBetween(state.now, now) != 0) _watchDay(now);
    emit(state.copyWith(now: now));
  }

  void _watchDay(DateTime now) {
    final day = CalendarDate.of(now);
    unawaited(_schedule?.cancel());
    _schedule = _jobs
        .watchScheduled(
          from: day,
          to: DateTime(day.year, day.month, day.day + 1),
        )
        .listen(
          (jobs) => emit(state.copyWith(schedule: jobs)),
          onError: addError,
        );
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _schedule?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
