import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_cubit.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_card_label.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_customer_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_missing_view.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_photos_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_progress_steps.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';
import 'package:salahly/features/marketplace/presentation/widgets/arrival_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One job: where it stands, who it is for, its photos, quote and money,
/// with its next step at the bottom.
class JobPage extends StatelessWidget {
  const JobPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          JobDetailsCubit(jobs: context.read(), jobId: jobId)..start(),
      child: const JobView(),
    );
  }
}

class JobView extends StatelessWidget {
  const JobView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<JobDetailsCubit, JobDetailsState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              current.status == JobDetailsStatus.deleted,
          listener: (context, state) {
            if (ModalRoute.of(context)?.isCurrent ?? false) context.pop();
          },
        ),
        BlocListener<JobDetailsCubit, JobDetailsState>(
          listenWhen: (previous, current) =>
              previous.change != current.change && current.change != null,
          listener: (context, state) => _showUndo(context, state.change!),
        ),
        BlocListener<JobDetailsCubit, JobDetailsState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  commonFailureMessage(
                    AppLocalizations.of(context),
                    state.failure!,
                  ),
                ),
              ),
            ),
        ),
      ],
      child: BlocBuilder<JobDetailsCubit, JobDetailsState>(
        builder: (context, state) {
          final details = state.details;
          if (details != null) {
            return _JobScreen(details: details, today: state.today);
          }
          return switch (state.status) {
            JobDetailsStatus.loading => const Scaffold(),
            _ => JobMissingView(
              title: AppLocalizations.of(context).jobUntitled,
            ),
          };
        },
      ),
    );
  }

  void _showUndo(BuildContext context, JobChange change) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobDetailsCubit>();
    final message = switch (change.to) {
      JobStatus.unconfirmed || JobStatus.confirmed => l10n.jobPageConfirmed,
      JobStatus.started => l10n.jobPageStarted,
      JobStatus.finished || JobStatus.paid => l10n.jobPageFinished,
      JobStatus.cancelled => l10n.jobPageCancelled,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: change.canUndo
              ? SnackBarAction(
                  label: l10n.jobPageUndo,
                  textColor: context.appColors.brassLight,
                  onPressed: () => cubit.undo(change),
                )
              : null,
        ),
      );
  }
}

class _JobScreen extends StatelessWidget {
  const _JobScreen({required this.details, required this.today});

  final JobDetails details;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final job = details.job;
    final isOffline = context.select<SyncCubit, bool>(
      (cubit) => cubit.state.isOffline,
    );
    final scheduledAt = job.scheduledAt;
    final description = job.description;
    final action = _mainAction(context);
    final isPlatform = job.source == JobSource.platform;

    return Scaffold(
      appBar: DetailHeader(
        title: jobTitle(l10n, job),
        subtitle: scheduledAt == null
            ? l10n.jobPageNoDate
            : '${dayLabel(l10n, scheduledAt, today: today)} '
                  '${timeLabel(l10n, scheduledAt)}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HeaderPill(details: details),
            _MoreMenu(job: job),
          ],
        ),
      ),
      body: PullToRefresh(
        onRefresh: () => context.read<SyncCubit>().syncNow(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isPlatform || (isOffline && !details.isSynced)) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isPlatform)
                      StatusPill(
                        label: l10n.jobFromPlatform,
                        tone: PillTone.dark,
                      ),
                    if (isOffline && !details.isSynced)
                      StatusPill(
                        label: l10n.jobPendingSync,
                        tone: PillTone.waiting,
                        icon: Icons.schedule_rounded,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (job.status != JobStatus.cancelled) ...[
              JobProgressSteps(status: job.status),
              const SizedBox(height: 14),
            ],
            JobCustomerCard(details: details),
            if (job.tags.isNotEmpty || description != null) ...[
              const SizedBox(height: 14),
              _ProblemCard(job: job),
            ],
            const SizedBox(height: 14),
            JobPhotosCard(details: details),
            const SizedBox(height: 14),
            _QuoteCard(details: details),
            const SizedBox(height: 14),
            _PaymentCard(details: details),
          ],
        ),
      ),
      bottomNavigationBar: action == null
          ? null
          : BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The consumer can be told once the visit is confirmed
                  // and until the work starts.
                  if (isPlatform && job.status == JobStatus.confirmed) ...[
                    ArrivalButton(jobId: job.id, isOffline: isOffline),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: action.$2,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(action.$1),
                  ),
                ],
              ),
            ),
    );
  }

  /// The button for the job's next step; none once it is paid or
  /// cancelled.
  (String, VoidCallback)? _mainAction(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobDetailsCubit>();
    final job = details.job;
    return switch (job.status) {
      JobStatus.unconfirmed => (l10n.jobPageConfirm, cubit.advance),
      JobStatus.confirmed => (l10n.jobPageStart, cubit.advance),
      JobStatus.started => (l10n.jobPageFinish, cubit.advance),
      JobStatus.finished => (
        l10n.jobPageCollect,
        () => context.push(AppRoutes.jobInvoice(job.id)),
      ),
      JobStatus.paid || JobStatus.cancelled => null,
    };
  }
}

/// The job's status in the top bar, in the words of its page:
/// "شغال دلوقتي", "خلصت · مستني الفلوس", ...
class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.details});

  final JobDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final status = details.job.status;
    final (label, background, foreground) = switch (status) {
      JobStatus.unconfirmed => (
        l10n.jobStatusUnconfirmed,
        colors.primarySoft,
        colors.primaryPressed,
      ),
      JobStatus.confirmed => (
        l10n.jobStatusConfirmed,
        colors.successSoft,
        colors.success,
      ),
      JobStatus.started => (
        l10n.jobPageStatusStarted,
        colors.warningSoft,
        colors.warning,
      ),
      JobStatus.finished when details.balancePiastres > 0 => (
        l10n.jobPageStatusAwaitingPayment,
        colors.warningSoft,
        colors.warning,
      ),
      JobStatus.finished => (
        l10n.jobStatusFinished,
        colors.successSoft,
        colors.success,
      ),
      JobStatus.paid => (
        l10n.jobStatusPaid,
        colors.successSoft,
        colors.success,
      ),
      JobStatus.cancelled => (
        l10n.jobStatusCancelled,
        colors.dangerSoft,
        colors.dangerDeep,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.5,
          color: foreground,
        ),
      ),
    );
  }
}

enum _MoreAction { reschedule, cancel, delete }

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // A platform job is the consumer's request too: it is never deleted,
    // and cancelling it can't be undone.
    final isPlatform = job.source == JobSource.platform;
    if (isPlatform && !job.status.isOpen) return const SizedBox.shrink();
    return PopupMenuButton<_MoreAction>(
      tooltip: l10n.jobPageMore,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        _MoreAction.reschedule => _reschedule(context),
        _MoreAction.cancel when isPlatform => _confirmCancel(context),
        _MoreAction.cancel => context.read<JobDetailsCubit>().cancel(),
        _MoreAction.delete => _confirmDelete(context),
      },
      itemBuilder: (context) => [
        if (job.status == JobStatus.unconfirmed ||
            job.status == JobStatus.confirmed)
          PopupMenuItem(
            value: _MoreAction.reschedule,
            child: Text(l10n.jobPageReschedule),
          ),
        if (job.status.isOpen)
          PopupMenuItem(
            value: _MoreAction.cancel,
            child: Text(l10n.jobPageCancel),
          ),
        if (!isPlatform)
          PopupMenuItem(
            value: _MoreAction.delete,
            child: Text(
              l10n.jobPageDelete,
              style: TextStyle(color: context.appColors.danger),
            ),
          ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobDetailsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.platformJobCancelTitle),
        content: Text(l10n.platformJobCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.jobPageKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.platformJobCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.cancel();
  }

  Future<void> _reschedule(BuildContext context) async {
    final cubit = context.read<JobDetailsCubit>();
    final choice = await showSchedulePicker(context, initial: job.scheduledAt);
    if (choice != null) await cubit.reschedule(choice.scheduledAt);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<JobDetailsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.jobPageDeleteTitle),
        content: Text(l10n.jobPageDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.jobPageKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.jobPageDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete();
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final description = job.description;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobCardLabel(l10n.jobPageProblem),
          if (job.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in job.tags)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.inkSoft,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      child: Text(
                        jobTagLabel(l10n, tag),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.details});

  final JobDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = details.job;
    final hasItems = details.items.isNotEmpty;
    final pill = switch (job.quoteStatus) {
      QuoteStatus.accepted => StatusPill(
        label: l10n.jobPageQuoteAccepted,
        tone: PillTone.success,
        icon: Icons.check_rounded,
      ),
      QuoteStatus.sent => StatusPill(
        label: l10n.jobQuoteSent,
        tone: PillTone.waiting,
        icon: Icons.schedule_rounded,
      ),
      QuoteStatus.declined => StatusPill(
        label: l10n.platformJobQuoteDeclined,
        tone: PillTone.danger,
        icon: Icons.close_rounded,
      ),
      QuoteStatus.draft when hasItems => StatusPill(
        label: l10n.jobPageQuoteDraft,
        tone: PillTone.attention,
      ),
      _ => null,
    };
    return AppCard(
      onTap: () => context.push(AppRoutes.jobQuote(job.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: JobCardLabel(l10n.jobPageQuote)),
              ?pill,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.jobPageItemCount(details.items.length),
                  style: TextStyle(fontSize: 15, color: colors.inkMuted),
                ),
              ),
              Text(
                hasItems
                    ? l10n.pounds(formatPounds(details.totalPiastres))
                    : l10n.jobPageQuoteCreate,
                style: hasItems
                    ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)
                    : TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.details});

  final JobDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final balance = details.balancePiastres;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobCardLabel(l10n.jobPagePayment),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Amount(
                  label: l10n.jobPagePaid,
                  piastres: details.paidPiastres,
                  color: colors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Amount(
                  label: l10n.jobPageBalance,
                  piastres: balance,
                  color: balance > 0 ? colors.danger : colors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Material(
            color: colors.inkSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => context.push(AppRoutes.jobInvoice(details.job.id)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: Text(
                    l10n.jobPageInvoice,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.label,
    required this.piastres,
    required this.color,
  });

  final String label;
  final int piastres;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14, color: context.appColors.inkMuted),
        ),
        Text(
          l10n.pounds(formatPounds(piastres)),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
