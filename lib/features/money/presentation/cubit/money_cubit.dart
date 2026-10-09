import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';

part 'money_state.dart';

/// The money tab: one month's income and everyone who still owes money.
///
/// Opens on the current month. Checks the clock every minute so lateness
/// moves on after midnight.
class MoneyCubit extends Cubit<MoneyState> {
  MoneyCubit({
    required this._jobs,
    this._clock = DateTime.now,
    this._tick = const Duration(minutes: 1),
  }) : super(MoneyState.on(_clock()));

  final JobsRepository _jobs;
  final DateTime Function() _clock;
  final Duration _tick;

  StreamSubscription<MonthIncome>? _income;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _ticker;

  void start() {
    _watchIncome(state.month);
    _subscriptions
      ..add(
        _jobs.watchAwaitingPayment().listen(
          (jobs) => emit(state.copyWith(awaitingPayment: jobs)),
          onError: addError,
        ),
      )
      ..add(
        _jobs.watchFirstFinishedAt().listen(
          (at) => emit(state.copyWith(firstFinishedAt: () => at)),
          onError: addError,
        ),
      );
    _ticker = Timer.periodic(
      _tick,
      (_) => emit(state.copyWith(today: CalendarDate.of(_clock()))),
    );
  }

  /// Shows the income of [month]; any time in it will do.
  void selectMonth(DateTime month) {
    final first = DateTime(month.year, month.month);
    if (first == state.month) return;
    emit(state.copyWith(month: first, income: () => null));
    _watchIncome(first);
  }

  void _watchIncome(DateTime month) {
    unawaited(_income?.cancel());
    _income = _jobs
        .watchMonthIncome(month)
        .listen(
          (income) => emit(state.copyWith(income: () => income)),
          onError: addError,
        );
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    await _income?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
