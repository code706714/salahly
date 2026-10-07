part of 'overview_cubit.dart';

final class OverviewState extends Equatable {
  const OverviewState({
    this.period = OverviewPeriod.week,
    this.overview,
    this.coverage,
    this.isLoading = true,
    this.failure,
  });

  final OverviewPeriod period;

  /// Null until the first load succeeds.
  final AdminOverview? overview;
  final AreaCoverageReport? coverage;
  final bool isLoading;

  /// Why the last load failed, if it did.
  final Failure? failure;

  OverviewState copyWith({
    OverviewPeriod? period,
    bool? isLoading,
    Failure? Function()? failure,
  }) {
    return OverviewState(
      period: period ?? this.period,
      overview: overview,
      coverage: coverage,
      isLoading: isLoading ?? this.isLoading,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [period, overview, coverage, isLoading, failure];
}
