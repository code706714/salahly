part of 'today_cubit.dart';

final class TodayState extends Equatable {
  const TodayState({
    required this.now,
    this.schedule,
    this.awaitingPayment = const [],
    this.hasJobs,
  });

  final DateTime now;

  /// Today's visits, soonest first; null until loaded.
  final List<JobSummary>? schedule;

  /// Finished jobs with money still owed.
  final List<JobSummary> awaitingPayment;

  /// Whether any job was ever recorded; null until known.
  final bool? hasJobs;

  bool get isLoading => schedule == null || hasJobs == null;

  /// A first day: nothing recorded yet, so the screen shows how to start.
  bool get isFirstDay => hasJobs == false;

  int get owedPiastres =>
      awaitingPayment.fold(0, (sum, job) => sum + job.balancePiastres);

  int get owingCustomers =>
      awaitingPayment.map((job) => job.job.customerId).toSet().length;

  /// The longest any owed money has been late, in days; zero when none is.
  int get mostDaysLate => awaitingPayment.fold(0, (most, job) {
    final days = PaymentDue.of(job.job, today: now).daysLate;
    return days > most ? days : most;
  });

  /// The visit to look at now: the one under way, else the first one still
  /// ahead of the clock.
  JobSummary? get current {
    final jobs = schedule ?? const <JobSummary>[];
    for (final summary in jobs) {
      if (summary.job.status == JobStatus.started) return summary;
    }
    for (final summary in jobs) {
      final job = summary.job;
      final end = job.scheduledAt!.add(Duration(minutes: job.durationMinutes));
      if (job.status.isOpen && end.isAfter(now)) return summary;
    }
    return null;
  }

  TodayState copyWith({
    DateTime? now,
    List<JobSummary>? schedule,
    List<JobSummary>? awaitingPayment,
    bool? hasJobs,
  }) {
    return TodayState(
      now: now ?? this.now,
      schedule: schedule ?? this.schedule,
      awaitingPayment: awaitingPayment ?? this.awaitingPayment,
      hasJobs: hasJobs ?? this.hasJobs,
    );
  }

  @override
  List<Object?> get props => [now, schedule, awaitingPayment, hasJobs];
}
