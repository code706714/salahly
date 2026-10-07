import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The four headline numbers of the overview.
class OverviewKpis extends StatelessWidget {
  const OverviewKpis({required this.overview, super.key});

  final AdminOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final requests = overview.requests;
    final unanswered = overview.unanswered;
    final rating = overview.rating;
    final progress = overview.verifiedTechnicianTarget == 0
        ? 0.0
        : (overview.verifiedTechnicians / overview.verifiedTechnicianTarget)
              .clamp(0, 1)
              .toDouble();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Kpi(
              title: l10n.adminKpiVerified,
              value: Text.rich(
                TextSpan(
                  text: '${overview.verifiedTechnicians} ',
                  children: [
                    TextSpan(
                      text: l10n.adminKpiOfTarget(
                        overview.verifiedTechnicianTarget,
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.divider,
                      color: colors.successBright,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Caption(l10n.adminKpiTargetCaption),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _Kpi(
              title: switch (overview.period) {
                OverviewPeriod.today => l10n.adminKpiRequestsToday,
                OverviewPeriod.week => l10n.adminKpiRequestsWeek,
                OverviewPeriod.month => l10n.adminKpiRequestsMonth,
              },
              value: Text('${requests.count}'),
              footer: _Caption(
                switch (requests.change) {
                  > 0 => l10n.adminKpiRequestsUp(requests.change),
                  < 0 => l10n.adminKpiRequestsDown(-requests.change),
                  _ => l10n.adminKpiRequestsSame,
                },
                color: requests.change > 0 ? colors.success : null,
                bold: requests.change > 0,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _Kpi(
              title: l10n.adminKpiNoOffers,
              alert: unanswered.count > 0,
              value: Text('${unanswered.count}'),
              footer: _Caption(
                l10n.adminKpiNoOffersCaption(unanswered.olderThanHours),
                color: unanswered.count > 0 ? colors.dangerDeep : null,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _Kpi(
              title: l10n.adminKpiRating,
              value: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rating.average == null
                        ? l10n.adminNone
                        : rating.average!.toStringAsFixed(1),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.star_rounded, size: 26, color: colors.brass),
                ],
              ),
              footer: _Caption(
                rating.count == 0
                    ? l10n.adminKpiRatingNone
                    : l10n.adminKpiRatingCaption(rating.count),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.title,
    required this.value,
    required this.footer,
    this.alert = false,
  });

  final String title;
  final Widget value;
  final Widget footer;

  /// Whether the number is a problem, which tints the card.
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      color: alert ? colors.dangerFaint : null,
      borderColor: alert ? colors.dangerLine : null,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: alert ? colors.dangerDeep : colors.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: alert ? colors.danger : colors.ink,
            ),
            child: value,
          ),
          const SizedBox(height: 4),
          footer,
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text, {this.color, this.bold = false});

  final String text;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        color: color ?? context.appColors.inkMuted,
      ),
    );
  }
}
