import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/repositories/activity_repository.dart';

part 'activity_state.dart';

/// The day's (or week's, or month's) money and what technicians did.
class ActivityCubit extends Cubit<ActivityState> {
  ActivityCubit(this._repository) : super(const ActivityState());

  final ActivityRepository _repository;
  int _generation = 0;

  Future<void> load() => _load();

  Future<void> selectPeriod(OverviewPeriod period) {
    if (period == state.period) return Future.value();
    emit(ActivityState(period: period));
    return _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final period = state.period;
    emit(state.copyWith(isLoading: true, failure: () => null));
    final results = await (
      _repository.fetchMoney(period),
      _repository.fetchTechnicians(period),
    ).wait;
    if (isClosed || generation != _generation) return;
    switch (results) {
      case (Ok(value: final money), Ok(value: final report)):
        emit(
          ActivityState(
            period: period,
            money: money,
            report: report,
            isLoading: false,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(isLoading: false, failure: () => failure));
    }
  }
}
