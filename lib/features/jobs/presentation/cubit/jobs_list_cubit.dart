import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/arabic_search.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';

part 'jobs_list_state.dart';

/// The jobs tab: what is coming, what needs following up and what is
/// done, searchable by customer, phone and work.
///
/// Checks the clock every minute and regroups once the day changes, so
/// "today" and the weeks stay right past midnight.
class JobsListCubit extends Cubit<JobsListState> {
  JobsListCubit({
    required this._jobs,
    required this._describe,
    this._clock = DateTime.now,
    this._tick = const Duration(minutes: 1),
  }) : super(JobsListState(now: _clock()));

  final JobsRepository _jobs;

  /// The words a job is found by besides its customer: what the work is.
  final String Function(Job job) _describe;
  final DateTime Function() _clock;
  final Duration _tick;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _ticker;
  List<JobSummary>? _open;
  List<JobSummary>? _awaitingPayment;
  List<JobSummary>? _closed;

  void start() {
    _subscriptions
      ..add(
        _jobs.watchOpen().listen((jobs) {
          _open = jobs;
          _emitGrouped(state);
        }, onError: addError),
      )
      ..add(
        _jobs.watchAwaitingPayment().listen((jobs) {
          _awaitingPayment = jobs;
          _emitGrouped(state);
        }, onError: addError),
      )
      ..add(
        _jobs.watchClosed().listen((jobs) {
          _closed = jobs;
          _emitGrouped(state);
        }, onError: addError),
      );
    _ticker = Timer.periodic(_tick, (_) => _onTick());
  }

  void selectTab(JobsTab tab) => emit(state.copyWith(tab: tab));

  void openSearch() => emit(state.copyWith(isSearching: true));

  void search(String query) => _emitGrouped(state.copyWith(query: query));

  /// Hides the search field and shows every job again.
  void closeSearch() =>
      _emitGrouped(state.copyWith(isSearching: false, query: ''));

  void _onTick() {
    final now = _clock();
    if (CalendarDate.daysBetween(state.now, now) == 0) return;
    _emitGrouped(state.copyWith(now: now));
  }

  /// Emits [next] with its sections grouped from the latest jobs, once all
  /// three lists have loaded.
  void _emitGrouped(JobsListState next) {
    final open = _open;
    final awaitingPayment = _awaitingPayment;
    final closed = _closed;
    if (open == null || awaitingPayment == null || closed == null) {
      emit(next);
      return;
    }
    List<JobSummary> matching(List<JobSummary> jobs) => [
      for (final summary in jobs)
        if (matchesJobQuery(summary, next.query, describe: _describe)) summary,
    ];
    final now = next.now;
    emit(
      next.copyWith(
        upcoming: upcomingSections(matching(open), now: now),
        followUp: followUpSections(
          open: matching(open),
          awaitingPayment: matching(awaitingPayment),
          now: now,
        ),
        done: doneSections(
          closed: matching(closed),
          awaitingPayment: matching(awaitingPayment),
          now: now,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    _ticker?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}

/// Whether [summary] matches what was typed in the search: part of the
/// customer's name or of the work ([describe]), ignoring the Arabic letter
/// variants people mix up, or digits of the customer's phone.
bool matchesJobQuery(
  JobSummary summary,
  String query, {
  required String Function(Job job) describe,
}) {
  final words = _fold(query);
  if (words.isEmpty) return true;
  if (_fold(summary.customerName).contains(words) ||
      _fold(describe(summary.job)).contains(words)) {
    return true;
  }
  final digits = digitsOnly(query);
  final phone = summary.customerPhone;
  return digits.isNotEmpty &&
      phone != null &&
      ('0${phone.nationalNumber}'.contains(digits) ||
          phone.international.contains(digits));
}

String _fold(String text) => foldArabic(text).toLowerCase();

/// Open jobs from the start of [now]'s day on, by day, soonest first.
List<JobsSection> upcomingSections(
  List<JobSummary> open, {
  required DateTime now,
}) {
  final today = CalendarDate.of(now);
  final scheduled = [
    for (final summary in open)
      if (summary.job.scheduledAt case final at? when !at.isBefore(today))
        summary,
  ]..sort((a, b) => a.job.scheduledAt!.compareTo(b.job.scheduledAt!));
  final byDay = <DateTime, List<JobSummary>>{};
  for (final summary in scheduled) {
    byDay
        .putIfAbsent(CalendarDate.of(summary.job.scheduledAt!), () => [])
        .add(summary);
  }
  return [
    for (final MapEntry(:key, :value) in byDay.entries) DaySection(key, value),
  ];
}

/// What needs following up, each job once: money owed, then quotes with no
/// answer, then visits whose day passed, then jobs with no date.
List<JobsSection> followUpSections({
  required List<JobSummary> open,
  required List<JobSummary> awaitingPayment,
  required DateTime now,
}) {
  final today = CalendarDate.of(now);
  final quotes = <JobSummary>[];
  final missed = <JobSummary>[];
  final unscheduled = <JobSummary>[];
  for (final summary in open) {
    final job = summary.job;
    final at = job.scheduledAt;
    if (job.quoteStatus == QuoteStatus.sent) {
      quotes.add(summary);
    } else if (at == null) {
      unscheduled.add(summary);
    } else if (at.isBefore(today)) {
      missed.add(summary);
    }
  }
  DateTime sentAt(JobSummary summary) =>
      summary.job.quoteSentAt ?? summary.job.updatedAt;
  quotes.sort((a, b) => sentAt(a).compareTo(sentAt(b)));
  return [
    if (awaitingPayment.isNotEmpty) AwaitingPaymentSection(awaitingPayment),
    if (quotes.isNotEmpty) QuotesWaitingSection(quotes),
    if (missed.isNotEmpty) MissedSection(missed),
    if (unscheduled.isNotEmpty) UnscheduledSection(unscheduled),
  ];
}

/// Finished, paid and cancelled jobs, most recent first: this week (from
/// Saturday), last week, then by month.
List<JobsSection> doneSections({
  required List<JobSummary> closed,
  required List<JobSummary> awaitingPayment,
  required DateTime now,
}) {
  final jobs = [...awaitingPayment, ...closed]
    ..sort((a, b) => closedAt(b.job).compareTo(closedAt(a.job)));
  final today = CalendarDate.of(now);
  final daysIntoWeek = (today.weekday - DateTime.saturday) % 7;
  final thisWeek = DateTime(today.year, today.month, today.day - daysIntoWeek);
  final lastWeek = DateTime(thisWeek.year, thisWeek.month, thisWeek.day - 7);

  final sections = <JobsSection>[];
  final current = <JobSummary>[];
  final previous = <JobSummary>[];
  final byMonth = <DateTime, List<JobSummary>>{};
  for (final summary in jobs) {
    final at = closedAt(summary.job);
    if (!at.isBefore(thisWeek)) {
      current.add(summary);
    } else if (!at.isBefore(lastWeek)) {
      previous.add(summary);
    } else {
      byMonth.putIfAbsent(DateTime(at.year, at.month), () => []).add(summary);
    }
  }
  if (current.isNotEmpty) sections.add(ThisWeekSection(current));
  if (previous.isNotEmpty) sections.add(LastWeekSection(previous));
  for (final MapEntry(:key, :value) in byMonth.entries) {
    sections.add(MonthSection(key, value));
  }
  return sections;
}

/// When a done job ended: the day it was cancelled, else finished.
DateTime closedAt(Job job) => job.status == JobStatus.cancelled
    ? job.cancelledAt ?? job.updatedAt
    : job.finishedAt ?? job.paidAt ?? job.updatedAt;
