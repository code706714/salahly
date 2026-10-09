part of 'calendar_cubit.dart';

/// One hour of the selected day with the visits that start in it.
final class CalendarSlot extends Equatable {
  const CalendarSlot(this.hour, this.jobs);

  /// 0 to 23.
  final int hour;

  /// Soonest first.
  final List<JobSummary> jobs;

  @override
  List<Object?> get props => [hour, jobs];
}

final class CalendarState extends Equatable {
  const CalendarState({
    required this.origin,
    required this.today,
    required this.selectedDay,
    this.week = 0,
    this.jobs,
  });

  /// The schedule always shows these hours, and earlier or later ones only
  /// for visits outside them.
  static const firstHour = 9;
  static const lastHour = 20;

  /// The first day of week 0, local midnight: the day the calendar opened.
  /// Weeks run seven days from it, so the strip starts with today.
  final DateTime origin;

  /// Local midnight.
  final DateTime today;

  /// Which seven days the strip shows, counted from [origin]; negative
  /// for the past.
  final int week;

  /// Local midnight; always within [week].
  final DateTime selectedDay;

  /// The week's visits, soonest first; null until loaded.
  final List<JobSummary>? jobs;

  DateTime get weekStart =>
      DateTime(origin.year, origin.month, origin.day + 7 * week);

  /// The strip's seven days, local midnight.
  List<DateTime> get days {
    final start = weekStart;
    return [
      for (var i = 0; i < 7; i++)
        DateTime(start.year, start.month, start.day + i),
    ];
  }

  /// Which week, counted from [origin], holds [day].
  int weekOf(DateTime day) =>
      (CalendarDate.daysBetween(origin, day) / 7).floor();

  List<JobSummary> jobsOn(DateTime day) => [
    for (final summary in jobs ?? const <JobSummary>[])
      if (CalendarDate.daysBetween(day, summary.job.scheduledAt!) == 0) summary,
  ];

  bool hasJobsOn(DateTime day) => jobsOn(day).isNotEmpty;

  /// The selected day hour by hour, from [firstHour] to [lastHour] or
  /// wider to take in every visit.
  List<CalendarSlot> get slots {
    final dayJobs = jobsOn(selectedDay);
    var first = firstHour;
    var last = lastHour;
    for (final summary in dayJobs) {
      final hour = summary.job.scheduledAt!.hour;
      if (hour < first) first = hour;
      if (hour > last) last = hour;
    }
    return [
      for (var hour = first; hour <= last; hour++)
        CalendarSlot(hour, [
          for (final summary in dayJobs)
            if (summary.job.scheduledAt!.hour == hour) summary,
        ]),
    ];
  }

  @override
  List<Object?> get props => [origin, today, week, selectedDay, jobs];
}
