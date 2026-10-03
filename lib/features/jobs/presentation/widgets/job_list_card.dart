import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_time.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A job in a list: its time, customer, work, amount and where it stands.
/// Opens the job when tapped.
class JobListCard extends StatelessWidget {
  const JobListCard({
    required this.summary,
    required this.pills,
    required this.amountPiastres,
    this.showsTime = true,
    super.key,
  });

  final JobSummary summary;

  /// Where the job stands, as the list it is in tells it. The card adds
  /// "من المنصة" and "هتتبعت" itself.
  final List<Widget> pills;

  /// The amount at the end of the first line; a dash when zero.
  final int amountPiastres;

  /// Whether to show the visit's time, when it has one.
  final bool showsTime;

  static const _timeWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = summary.job;
    final isOffline = context.select<SyncCubit, bool>(
      (cubit) => cubit.state.isOffline,
    );
    final at = job.scheduledAt;

    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push(AppRoutes.job(job.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showsTime && at != null)
            JobTime(
              time: at,
              color: colors.ink,
              width: _timeWidth,
              fontSize: 16,
            )
          else
            const SizedBox(width: _timeWidth),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        summary.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      amountPiastres > 0
                          ? formatPounds(amountPiastres)
                          : l10n.jobsListNoAmount,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  jobTitle(l10n, job),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.inkMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...pills,
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
