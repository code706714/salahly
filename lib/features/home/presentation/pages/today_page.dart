import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/core/widgets/offline_banner.dart';
import 'package:salahly/core/widgets/section_header.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/home/presentation/cubit/today_cubit.dart';
import 'package:salahly/features/home/presentation/widgets/verification_banner.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_status_pill.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_time.dart';
import 'package:salahly/features/jobs/presentation/widgets/new_job_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's first tab: today's visits and the money still out.
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TodayCubit(jobs: context.read())..start(),
      child: const TodayView(),
    );
  }
}

class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    // Briefly null while signing out, before the redirect.
    if (profile == null) return const Scaffold();
    final state = context.watch<TodayCubit>().state;
    final showsJobs = !state.isLoading && !state.isFirstDay;

    return Scaffold(
      floatingActionButton: showsJobs ? const NewJobButton() : null,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, showsJobs ? 140 : 24),
          children: [
            _Header(
              profile: profile,
              now: state.now,
              isFirstDay: state.isFirstDay,
            ),
            VerificationBanner(
              status: profile.technician?.verificationStatus,
              padding: const EdgeInsets.only(top: 16),
            ),
            const OfflineBanner(padding: EdgeInsets.only(top: 16)),
            if (state.isFirstDay)
              const _FirstSteps()
            else if (showsJobs) ...[
              if (state.owedPiastres > 0) ...[
                const SizedBox(height: 16),
                _OwedCard(state: state),
              ],
              const SizedBox(height: 20),
              SectionHeader(
                title: AppLocalizations.of(context).todayScheduleTitle,
                note: AppLocalizations.of(
                  context,
                ).jobCount(state.schedule!.length),
              ),
              const SizedBox(height: 16),
              ..._schedule(state, profile),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _schedule(TodayState state, UserProfile profile) {
    final jobs = state.schedule!;
    if (jobs.isEmpty) return const [_NoJobsToday()];
    final current = state.current;
    return [
      for (final (index, summary) in jobs.indexed) ...[
        if (index > 0) const SizedBox(height: 16),
        _JobCard(
          summary: summary,
          highlight: summary == current,
          now: state.now,
          technicianName: profile.fullName,
        ),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.now,
    required this.isFirstDay,
  });

  final UserProfile profile;
  final DateTime now;
  final bool isFirstDay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final name = profile.firstName;
    final greeting = isFirstDay
        ? l10n.greeting(name)
        : now.hour < 12
        ? l10n.goodMorning(name)
        : l10n.goodEvening(name);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                weekdayDate(now),
                style: TextStyle(fontSize: 14, color: colors.inkMuted),
              ),
              const SizedBox(height: 2),
              Semantics(
                header: true,
                child: Text(
                  greeting,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: l10n.myAccount,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => context.push(AppRoutes.technicianAccount),
            child: InitialsAvatar(name: profile.fullName),
          ),
        ),
      ],
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.state});

  final TodayState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final daysLate = state.mostDaysLate;
    return AppCard(
      onTap: () => context.go(AppRoutes.technicianMoney),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todayOwedTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                MoneyText(
                  state.owedPiastres,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: colors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.todayOwedCustomers(state.owingCustomers) +
                      (daysLate > 0 ? l10n.todayOwedLatest(daysLate) : ''),
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.todayOwedSeeWho,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.summary,
    required this.highlight,
    required this.now,
    required this.technicianName,
  });

  final JobSummary summary;

  /// The visit under way or next up.
  final bool highlight;
  final DateTime now;
  final String technicianName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = summary.job;
    final isDone = job.status.isDone;
    final isOffline = context.select<SyncCubit, bool>(
      (cubit) => cubit.state.isOffline,
    );
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(summary.customerAreaId),
    );
    final place = [?summary.address, ?areaName].join('، ');
    final phone = summary.customerPhone;

    final card = AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderColor: highlight ? colors.primary : null,
      borderWidth: highlight ? 2 : 1.5,
      onTap: () => context.push(AppRoutes.job(job.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JobTime(
            time: job.scheduledAt!,
            color: highlight
                ? colors.primary
                : isDone
                ? colors.inkMuted
                : colors.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (highlight)
                      Text(
                        job.status == JobStatus.started
                            ? l10n.jobNow
                            : l10n.jobNext,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  jobTitle(l10n, job),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 16,
                        color: colors.inkMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    JobStatusPill(job.status),
                    if (summary.awaitsPayment)
                      StatusPill(
                        label: l10n.jobAwaitingAmount(
                          formatPounds(summary.balancePiastres),
                        ),
                        tone: PillTone.waiting,
                        icon: Icons.schedule_rounded,
                      ),
                    if (job.status.isOpen &&
                        job.quoteStatus == QuoteStatus.sent)
                      StatusPill(
                        label: l10n.jobQuoteSent,
                        tone: PillTone.waiting,
                      ),
                    if (job.source == JobSource.platform)
                      StatusPill(
                        label: l10n.jobFromPlatform,
                        tone: PillTone.dark,
                      ),
                    if (isOffline && !summary.isSynced)
                      StatusPill(
                        label: l10n.jobPendingSync,
                        tone: PillTone.waiting,
                        icon: Icons.schedule_rounded,
                      ),
                    if (job.status == JobStatus.unconfirmed && phone != null)
                      WhatsAppButton(
                        label: l10n.jobSendConfirmation,
                        size: WhatsAppButtonSize.small,
                        onPressed: () => context.sendOnWhatsApp(
                          confirmationMessage(
                            l10n,
                            job: job,
                            customerName: summary.customerName,
                            technicianName: technicianName,
                            today: now,
                          ),
                          to: phone,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return isDone ? Opacity(opacity: 0.85, child: card) : card;
  }
}

class _NoJobsToday extends StatelessWidget {
  const _NoJobsToday();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            l10n.todayNoJobs,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.todayNoJobsHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// A first day: how to get started instead of an empty schedule.
class _FirstSteps extends StatelessWidget {
  const _FirstSteps();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 34),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.inkSoft,
              borderRadius: BorderRadius.circular(AppRadii.xxl),
            ),
            child: Icon(
              Icons.calendar_today_outlined,
              size: 32,
              color: colors.ink,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.todayNoJobs,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.todayFirstSteps,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
        ),
        const SizedBox(height: 22),
        _Step(
          number: 1,
          title: l10n.todayStepFirstJob,
          hint: l10n.todayStepFirstJobHint,
          onTap: () => context.push(AppRoutes.newJob),
        ),
        const SizedBox(height: 16),
        _Step(
          number: 2,
          title: l10n.todayStepContacts,
          hint: l10n.todayStepContactsHint,
          onTap: () => context.push(AppRoutes.newCustomerFromContacts),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  final int number;
  final String title;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hint,
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: colors.primary),
        ],
      ),
    );
  }
}
