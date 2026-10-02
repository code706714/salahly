part of 'money_cubit.dart';

/// A job with money still owed and where that money stands.
final class OwedJob extends Equatable {
  const OwedJob(this.summary, this.due);

  final JobSummary summary;
  final PaymentDue due;

  /// Whether to remind the customer on WhatsApp: the money is late or
  /// promised, and there is a phone to send to. Money due today is
  /// collected on the spot instead.
  bool get canRemind =>
      due is! PaymentDueToday && summary.customerPhone != null;

  @override
  List<Object?> get props => [summary, due];
}

final class MoneyState extends Equatable {
  const MoneyState({
    required this.today,
    required this.month,
    this.income,
    this.awaitingPayment,
    this.firstFinishedAt,
  });

  /// [now]'s day, showing its month.
  factory MoneyState.on(DateTime now) => MoneyState(
    today: CalendarDate.of(now),
    month: DateTime(now.year, now.month),
  );

  /// Local midnight of the day the money is judged by.
  final DateTime today;

  /// The first day of the month whose income is shown.
  final DateTime month;

  /// The income of [month]; null until loaded.
  final MonthIncome? income;

  /// Finished jobs with money still owed, oldest first; null until loaded.
  final List<JobSummary>? awaitingPayment;

  /// When the earliest counted job was finished; null when none was.
  final DateTime? firstFinishedAt;

  bool get isCurrentMonth => month == DateTime(today.year, today.month);

  /// The months to pick from, newest first: from this month back to the
  /// month of the first finished job.
  List<DateTime> get months {
    final current = DateTime(today.year, today.month);
    final first = firstFinishedAt;
    final oldest = first == null || first.isAfter(current)
        ? current
        : DateTime(first.year, first.month);
    return [
      for (
        var month = current;
        !month.isBefore(oldest);
        month = DateTime(month.year, month.month - 1)
      )
        month,
    ];
  }

  /// Who owes money, the most late first. Jobs as late, or not late, keep
  /// the repository's order: the one finished first comes first.
  List<OwedJob> get owed {
    final owed = [
      for (final summary in awaitingPayment ?? const <JobSummary>[])
        OwedJob(summary, PaymentDue.of(summary.job, today: today)),
    ];
    final order = List.generate(owed.length, (index) => index)
      ..sort((a, b) {
        final byLateness = owed[b].due.daysLate - owed[a].due.daysLate;
        return byLateness != 0 ? byLateness : a - b;
      });
    return [for (final index in order) owed[index]];
  }

  /// How many different customers owe money.
  int get owingCustomers => {
    for (final summary in awaitingPayment ?? const <JobSummary>[])
      summary.job.customerId,
  }.length;

  MoneyState copyWith({
    DateTime? today,
    DateTime? month,
    MonthIncome? Function()? income,
    List<JobSummary>? awaitingPayment,
    DateTime? Function()? firstFinishedAt,
  }) {
    return MoneyState(
      today: today ?? this.today,
      month: month ?? this.month,
      income: income == null ? this.income : income(),
      awaitingPayment: awaitingPayment ?? this.awaitingPayment,
      firstFinishedAt: firstFinishedAt == null
          ? this.firstFinishedAt
          : firstFinishedAt(),
    );
  }

  @override
  List<Object?> get props => [
    today,
    month,
    income,
    awaitingPayment,
    firstFinishedAt,
  ];
}
