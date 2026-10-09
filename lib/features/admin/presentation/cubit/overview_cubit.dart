import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';

part 'overview_state.dart';

/// The overview's numbers and the coverage by area for one period.
///
/// The whole console shares one: its counts of what waits for the team also
/// badge the side menu, and pages refresh it after they review something.
class OverviewCubit extends Cubit<OverviewState> {
  OverviewCubit(this._repository) : super(const OverviewState());

  final OverviewRepository _repository;

  /// How many areas the coverage table asks for, the most the server gives.
  static const areaLimit = 100;

  int _generation = 0;

  Future<void> load() => _load(showSpinner: true);

  Future<void> selectPeriod(OverviewPeriod period) {
    if (period == state.period) return Future.value();
    emit(state.copyWith(period: period));
    return _load(showSpinner: true);
  }

  /// Fetches the numbers again without clearing what is shown.
  Future<void> refresh() => _load(showSpinner: false);

  Future<void> _load({required bool showSpinner}) async {
    final generation = ++_generation;
    final period = state.period;
    emit(
      state.copyWith(
        isLoading: showSpinner || state.overview == null,
        failure: () => null,
      ),
    );
    final results = await (
      _repository.fetchOverview(period),
      _repository.fetchAreas(period, limit: areaLimit, offset: 0),
    ).wait;
    if (isClosed || generation != _generation) return;
    switch (results) {
      case (Ok(value: final overview), Ok(value: final areas)):
        emit(
          OverviewState(
            period: period,
            overview: overview,
            coverage: areas,
            isLoading: false,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(isLoading: false, failure: () => failure));
    }
  }
}
