part of 'activity_cubit.dart';

final class ActivityState extends Equatable {
  const ActivityState({
    this.period = OverviewPeriod.today,
    this.money,
    this.report,
    this.isLoading = true,
    this.failure,
  });

  final OverviewPeriod period;

  /// Null until the first load succeeds.
  final MoneySummary? money;
  final ActivityReport? report;
  final bool isLoading;

  /// Why the last load failed, if it did.
  final Failure? failure;

  ActivityState copyWith({
    bool? isLoading,
    Failure? Function()? failure,
  }) {
    return ActivityState(
      period: period,
      money: money,
      report: report,
      isLoading: isLoading ?? this.isLoading,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [period, money, report, isLoading, failure];
}
