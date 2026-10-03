part of 'customer_cubit.dart';

final class CustomerState extends Equatable {
  const CustomerState({
    required this.today,
    this.record,
    this.isGone = false,
    this.jobs,
    this.failure,
  });

  /// Local midnight of the day the page opened.
  final DateTime today;

  /// The customer and their units; null until loaded.
  final CustomerRecord? record;

  /// The customer was deleted, here or on another phone.
  final bool isGone;

  /// Their jobs, most recent first; null until loaded.
  final List<JobSummary>? jobs;

  /// Why the last change to a unit failed.
  final Failure? failure;

  bool get isLoading => !isGone && (record == null || jobs == null);

  /// Finished jobs not fully paid, oldest first.
  List<JobSummary> get owedJobs {
    final owed = [
      for (final summary in jobs ?? const <JobSummary>[])
        if (summary.awaitsPayment) summary,
    ];
    return owed..sort((a, b) => _finished(a).compareTo(_finished(b)));
  }

  static DateTime _finished(JobSummary summary) =>
      summary.job.finishedAt ?? summary.job.updatedAt;

  /// What the customer still owes.
  int get owedPiastres =>
      owedJobs.fold(0, (sum, summary) => sum + summary.balancePiastres);

  /// What was paid of the jobs still owed.
  int get owedPaidPiastres =>
      owedJobs.fold(0, (sum, summary) => sum + summary.paidPiastres);

  /// The total of the jobs still owed.
  int get owedTotalPiastres =>
      owedJobs.fold(0, (sum, summary) => sum + summary.totalPiastres);

  /// The soonest next service of their units, or null.
  DateTime? get nextServiceOn {
    DateTime? soonest;
    for (final unit in record?.units ?? const <CustomerUnit>[]) {
      final day = unit.nextServiceOn;
      if (day != null && (soonest == null || day.isBefore(soonest))) {
        soonest = day;
      }
    }
    return soonest;
  }

  CustomerState copyWith({
    CustomerRecord? record,
    bool? isGone,
    List<JobSummary>? jobs,
    Failure? Function()? failure,
  }) {
    return CustomerState(
      today: today,
      record: record ?? this.record,
      isGone: isGone ?? this.isGone,
      jobs: jobs ?? this.jobs,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [today, record, isGone, jobs, failure];
}
