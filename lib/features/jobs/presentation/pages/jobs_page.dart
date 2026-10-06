import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/core/widgets/square_icon_button.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/presentation/cubit/jobs_list_cubit.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_list_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_status_pill.dart';
import 'package:salahly/features/jobs/presentation/widgets/new_job_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Jobs tab: upcoming, follow-up and closed jobs.
class JobsPage extends StatelessWidget {
  const JobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocProvider(
      create: (context) => JobsListCubit(
        jobs: context.read(),
        describe: (job) => '${jobTitle(l10n, job)} ${job.description ?? ''}',
      )..start(),
      child: const JobsView(),
    );
  }
}

class JobsView extends StatelessWidget {
  const JobsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobsListCubit>();
    final state = context.watch<JobsListCubit>().state;

    String tabLabel(JobsTab tab, String label) {
      final count = state.countOf(tab);
      return count > 0 ? l10n.jobsListTabCount(label, count) : label;
    }

    return Scaffold(
      floatingActionButton: const NewJobButton(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isSearching)
                    const _SearchField()
                  else
                    const _Header(),
                  const SizedBox(height: 14),
                  SegmentedTabs(
                    labels: [
                      tabLabel(JobsTab.upcoming, l10n.jobsListUpcoming),
                      tabLabel(JobsTab.followUp, l10n.jobsListFollowUp),
                      l10n.jobsListDone,
                    ],
                    selected: state.tab.index,
                    onSelected: (index) =>
                        cubit.selectTab(JobsTab.values[index]),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  ? const SizedBox.shrink()
                  : _JobsList(state: state),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l10n.navJobs,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
        SquareIconButton(
          icon: Icons.calendar_today_outlined,
          tooltip: l10n.jobsListCalendar,
          onPressed: () => context.push(AppRoutes.technicianCalendar),
        ),
        const SizedBox(width: 8),
        SquareIconButton(
          icon: Icons.search_rounded,
          tooltip: l10n.jobsListSearch,
          onPressed: context.read<JobsListCubit>().openSearch,
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobsListCubit>();
    return Row(
      children: [
        Expanded(
          child: TextField(
            autofocus: true,
            onChanged: cubit.search,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: l10n.jobsListSearchHint,
              hintStyle: TextStyle(
                fontSize: 16,
                color: context.appColors.inkMuted,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SquareIconButton(
          icon: Icons.close_rounded,
          tooltip: l10n.jobsListSearchClose,
          onPressed: cubit.closeSearch,
        ),
      ],
    );
  }
}

class _JobsList extends StatelessWidget {
  const _JobsList({required this.state});

  final JobsListState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sections = state.sectionsOf(state.tab);
    final now = state.now;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
      children: [
        if (sections.isEmpty)
          _Empty(tab: state.tab, isSearch: state.query.trim().isNotEmpty),
        for (final (index, section) in sections.indexed) ...[
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              4,
              index == 0 ? 6 : 16,
              4,
              8,
            ),
            child: Semantics(
              header: true,
              child: Text(
                _heading(l10n, section, now: now),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.appColors.inkMuted,
                ),
              ),
            ),
          ),
          for (final (index, summary) in section.jobs.indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _card(l10n, section, summary, now: now),
          ],
        ],
      ],
    );
  }

  static String _heading(
    AppLocalizations l10n,
    JobsSection section, {
    required DateTime now,
  }) => switch (section) {
    DaySection(:final day) => switch (CalendarDate.daysBetween(now, day)) {
      0 => '${l10n.today} · ${weekdayDate(day)}',
      1 => '${l10n.tomorrow} · ${weekdayName(day)}',
      _ => weekdayDate(day),
    },
    AwaitingPaymentSection() => l10n.jobsListAwaitingPayment,
    QuotesWaitingSection() => l10n.jobsListQuotesWaiting,
    MissedSection() => l10n.jobsListMissed,
    UnscheduledSection() => l10n.jobsListUnscheduled,
    ThisWeekSection() => l10n.jobsListThisWeek,
    LastWeekSection() => l10n.jobsListLastWeek,
    MonthSection(:final month) => DateFormat(
      month.year == now.year ? 'MMMM' : 'MMMM y',
      'ar',
    ).format(month),
  };

  static Widget _card(
    AppLocalizations l10n,
    JobsSection section,
    JobSummary summary, {
    required DateTime now,
  }) {
    final job = summary.job;
    return switch (section) {
      DaySection() || UnscheduledSection() => JobListCard(
        summary: summary,
        amountPiastres: summary.totalPiastres,
        pills: _openPills(l10n, job),
      ),
      AwaitingPaymentSection() => JobListCard(
        summary: summary,
        amountPiastres: summary.balancePiastres,
        showsTime: false,
        pills: [_duePill(l10n, summary, now: now)],
      ),
      QuotesWaitingSection() => JobListCard(
        summary: summary,
        amountPiastres: summary.totalPiastres,
        showsTime: false,
        pills: [
          StatusPill(
            label: switch (job.quoteSentAt) {
              final sentAt? => l10n.jobsListQuoteSentAgo(
                CalendarDate.daysBetween(sentAt, now),
              ),
              null => l10n.jobQuoteSent,
            },
            tone: PillTone.waiting,
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
      MissedSection() => JobListCard(
        summary: summary,
        amountPiastres: summary.totalPiastres,
        pills: [
          JobStatusPill(job.status),
          StatusPill(
            label: l10n.jobsListWasDue(
              dayLabel(l10n, job.scheduledAt!, today: now),
            ),
            tone: PillTone.danger,
            icon: Icons.event_busy_outlined,
          ),
        ],
      ),
      ThisWeekSection() || LastWeekSection() || MonthSection() => JobListCard(
        summary: summary,
        amountPiastres: summary.totalPiastres,
        pills: [_donePill(l10n, summary)],
      ),
    };
  }

  /// Where an open job stands; a sent quote with no answer says so instead
  /// of "not confirmed yet", and a price increase the consumer declined
  /// says so too.
  static List<Widget> _openPills(AppLocalizations l10n, Job job) {
    final quoteSent = job.quoteStatus == QuoteStatus.sent;
    return [
      if (!quoteSent || job.status != JobStatus.unconfirmed)
        JobStatusPill(job.status),
      if (quoteSent)
        StatusPill(label: l10n.jobQuoteSent, tone: PillTone.waiting),
      if (job.quoteStatus == QuoteStatus.declined)
        StatusPill(label: l10n.platformJobQuoteDeclined, tone: PillTone.danger),
    ];
  }

  static Widget _duePill(
    AppLocalizations l10n,
    JobSummary summary, {
    required DateTime now,
  }) {
    final due = PaymentDue.of(summary.job, today: now);
    final label = paymentDueLabel(l10n, due, today: now);
    return StatusPill(
      label: summary.paidPiastres > 0
          ? '${l10n.jobsListPartlyPaid} · $label'
          : label,
      tone: due is PaymentLate ? PillTone.danger : PillTone.waiting,
      icon: Icons.schedule_rounded,
    );
  }

  static Widget _donePill(AppLocalizations l10n, JobSummary summary) {
    final job = summary.job;
    if (job.status == JobStatus.paid) {
      return StatusPill(
        label: '${l10n.jobStatusFinished} · ${l10n.jobStatusPaid}',
        tone: PillTone.success,
        icon: Icons.check_rounded,
      );
    }
    if (summary.awaitsPayment) {
      final owed = summary.paidPiastres > 0
          ? l10n.jobsListPartlyPaid
          : l10n.jobsListAwaitingMoney;
      return StatusPill(
        label: '${l10n.jobStatusFinished} · $owed',
        tone: PillTone.waiting,
        icon: Icons.schedule_rounded,
      );
    }
    return JobStatusPill(job.status);
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab, required this.isSearch});

  final JobsTab tab;

  /// Nothing matched the search, rather than nothing at all.
  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final (title, hint) = isSearch
        ? (l10n.jobsListNoResults, l10n.jobsListNoResultsHint)
        : switch (tab) {
            JobsTab.upcoming => (
              l10n.jobsListNoUpcoming,
              l10n.jobsListNoUpcomingHint,
            ),
            JobsTab.followUp => (
              l10n.jobsListNoFollowUp,
              l10n.jobsListNoFollowUpHint,
            ),
            JobsTab.done => (l10n.jobsListNoDone, l10n.jobsListNoDoneHint),
          };
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
