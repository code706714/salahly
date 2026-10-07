import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What waits for the team: submissions, unanswered requests, complaints,
/// transfers, and technicians whose rating dropped. Each opens its page.
class OverviewAttention extends StatelessWidget {
  const OverviewAttention({
    required this.overview,
    required this.now,
    super.key,
  });

  final AdminOverview overview;

  /// The time ages are counted from.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final verifications = overview.pendingVerifications;
    final unanswered = overview.unanswered;
    final complaints = overview.openComplaints;
    final topups = overview.pendingTopups;

    final items = [
      if (verifications.count > 0)
        _Item(
          route: AdminRoutes.verification,
          icon: Icons.badge_outlined,
          background: colors.warningSoft,
          foreground: colors.warning,
          title: l10n.adminAttentionVerifications(verifications.count),
          subtitle: verifications.oldestAt == null
              ? null
              : l10n.adminAttentionOldest(
                  adminAgeLabel(l10n, verifications.oldestAt!, now: now),
                ),
        ),
      if (unanswered.count > 0)
        _Item(
          route: AdminRoutes.requests,
          icon: Icons.schedule_rounded,
          background: colors.dangerSoft,
          foreground: colors.dangerDeep,
          title: l10n.adminAttentionNoOffers(unanswered.count),
          subtitle: unanswered.topAreas.isEmpty
              ? null
              : l10n.adminAttentionNoOffersAreas(
                  unanswered.topAreas.map((area) => area.name).join('، '),
                ),
        ),
      if (complaints.count > 0)
        _Item(
          route: AdminRoutes.requests,
          icon: Icons.outlined_flag_rounded,
          background: colors.primarySoft,
          foreground: colors.primaryPressed,
          title: l10n.adminAttentionComplaints(complaints.count),
          subtitle: _complaintReasons(l10n, complaints),
        ),
      if (topups.count > 0)
        _Item(
          route: AdminRoutes.transfers,
          icon: Icons.account_balance_wallet_outlined,
          background: colors.inkSoft,
          foreground: colors.ink,
          title: l10n.adminAttentionTopups(topups.count),
          subtitle: l10n.adminAttentionTopupsSplit(
            topups.technicians,
            topups.consumers,
          ),
        ),
      for (final technician in overview.lowRated)
        _Item(
          route: AdminRoutes.users,
          icon: Icons.warning_amber_rounded,
          background: colors.dangerSoft,
          foreground: colors.dangerDeep,
          title: l10n.adminAttentionLowRated,
          subtitle: l10n.adminAttentionLowRatedLine(
            technician.name,
            technician.rating.toStringAsFixed(1),
            technician.reviewCount,
          ),
        ),
    ];

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminAttentionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              l10n.adminAttentionNothing,
              style: TextStyle(fontSize: 15, color: colors.inkMuted),
            )
          else
            for (final item in items) ...[
              _ItemTile(item),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  /// The reasons of the open complaints, most common first: "الشغل مش
  /// مظبوط (2)، حاجة تانية (1)".
  static String? _complaintReasons(
    AppLocalizations l10n,
    OpenComplaints complaints,
  ) {
    final entries = complaints.byReason.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;
    return entries
        .map(
          (entry) =>
              '${adminComplaintReasonLabel(l10n, entry.key)} (${entry.value})',
        )
        .join('، ');
  }
}

class _Item {
  const _Item({
    required this.route,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    this.subtitle,
  });

  final String route;
  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String? subtitle;
}

class _ItemTile extends StatelessWidget {
  const _ItemTile(this.item);

  final _Item item;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.background,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: () => context.go(item.route),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: item.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(item.icon, size: 22, color: item.foreground),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.subtitle != null)
                      Text(
                        item.subtitle!,
                        style: TextStyle(fontSize: 13, color: colors.inkMuted),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
