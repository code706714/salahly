import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';

part 'settings_state.dart';

/// The settings the page shows: free uses, packs, payment accounts, and the
/// areas with how well each is covered.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required this._settingsRepository,
    required this._overviewRepository,
  }) : super(const SettingsState());

  final SettingsRepository _settingsRepository;
  final OverviewRepository _overviewRepository;

  /// How many areas are asked for, the most the server gives.
  static const areaLimit = 100;

  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    emit(state.copyWith(isLoading: true, failure: () => null));
    final results = await (
      _settingsRepository.fetchSettings(),
      _overviewRepository.fetchAreas(
        OverviewPeriod.month,
        limit: areaLimit,
        offset: 0,
      ),
    ).wait;
    if (isClosed || generation != _generation) return;
    switch (results) {
      case (Ok(value: final settings), Ok(value: final areas)):
        emit(
          SettingsState(settings: settings, coverage: areas, isLoading: false),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(state.copyWith(isLoading: false, failure: () => failure));
    }
  }
}
