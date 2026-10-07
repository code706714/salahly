part of 'settings_cubit.dart';

final class SettingsState extends Equatable {
  const SettingsState({
    this.settings,
    this.coverage,
    this.isLoading = true,
    this.failure,
  });

  /// Null until the first load succeeds.
  final AdminSettings? settings;
  final AreaCoverageReport? coverage;
  final bool isLoading;

  /// Why the last load failed, if it did.
  final Failure? failure;

  SettingsState copyWith({bool? isLoading, Failure? Function()? failure}) {
    return SettingsState(
      settings: settings,
      coverage: coverage,
      isLoading: isLoading ?? this.isLoading,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [settings, coverage, isLoading, failure];
}
