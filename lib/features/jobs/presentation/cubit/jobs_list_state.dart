part of 'jobs_list_cubit.dart';

/// The three lists of the jobs tab.
enum JobsTab { upcoming, followUp, done }

/// A titled run of jobs on the jobs tab. The kind of section sets its
/// heading and what its cards show.
sealed class JobsSection extends Equatable {
  const JobsSection(this.jobs);

  final List<JobSummary> jobs;

  @override
  List<Object?> get props => [jobs];
}

/// Upcoming visits on one [day], local midnight.
final class DaySection extends JobsSection {
  const DaySection(this.day, super.jobs);

  final DateTime day;

  @override
  List<Object?> get props => [day, jobs];
}

/// Finished jobs the customer still owes money for, oldest first.
final class AwaitingPaymentSection extends JobsSection {
  const AwaitingPaymentSection(super.jobs);
}

/// Open jobs whose quote was sent with no answer yet, longest waiting first.
final class QuotesWaitingSection extends JobsSection {
  const QuotesWaitingSection(super.jobs);
}

/// Open jobs whose day passed before they were finished.
final class MissedSection extends JobsSection {
  const MissedSection(super.jobs);
}

/// Open jobs with no date yet.
final class UnscheduledSection extends JobsSection {
  const UnscheduledSection(super.jobs);
}

/// Jobs closed since Saturday.
final class ThisWeekSection extends JobsSection {
  const ThisWeekSection(super.jobs);
}

/// Jobs closed the week before this one.
final class LastWeekSection extends JobsSection {
  const LastWeekSection(super.jobs);
}

/// Older closed jobs of one [month], the 1st at local midnight.
final class MonthSection extends JobsSection {
  const MonthSection(this.month, super.jobs);

  final DateTime month;

  @override
  List<Object?> get props => [month, jobs];
}

final class JobsListState extends Equatable {
  const JobsListState({
    required this.now,
    this.tab = JobsTab.upcoming,
    this.isSearching = false,
    this.query = '',
    this.upcoming,
    this.followUp,
    this.done,
  });

  final DateTime now;
  final JobsTab tab;

  /// Whether the header shows the search field.
  final bool isSearching;

  /// What the lists are filtered by; empty shows everything.
  final String query;

  /// Each tab's sections, filtered by [query]; null until loaded.
  final List<JobsSection>? upcoming;
  final List<JobsSection>? followUp;
  final List<JobsSection>? done;

  bool get isLoading => upcoming == null || followUp == null || done == null;

  List<JobsSection> sectionsOf(JobsTab tab) =>
      switch (tab) {
        JobsTab.upcoming => upcoming,
        JobsTab.followUp => followUp,
        JobsTab.done => done,
      } ??
      const [];

  /// How many different jobs [tab] lists.
  int countOf(JobsTab tab) => {
    for (final section in sectionsOf(tab))
      for (final summary in section.jobs) summary.job.id,
  }.length;

  JobsListState copyWith({
    DateTime? now,
    JobsTab? tab,
    bool? isSearching,
    String? query,
    List<JobsSection>? upcoming,
    List<JobsSection>? followUp,
    List<JobsSection>? done,
  }) {
    return JobsListState(
      now: now ?? this.now,
      tab: tab ?? this.tab,
      isSearching: isSearching ?? this.isSearching,
      query: query ?? this.query,
      upcoming: upcoming ?? this.upcoming,
      followUp: followUp ?? this.followUp,
      done: done ?? this.done,
    );
  }

  @override
  List<Object?> get props => [
    now,
    tab,
    isSearching,
    query,
    upcoming,
    followUp,
    done,
  ];
}
