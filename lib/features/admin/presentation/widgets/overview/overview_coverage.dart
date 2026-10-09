import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// How well each area is covered: technicians, requests, how many got an
/// offer, and whether ads run there.
class OverviewCoverage extends StatelessWidget {
  const OverviewCoverage({required this.report, super.key});

  final AreaCoverageReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminCoverageTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            l10n.adminCoverageHint(report.adsMinTechnicians),
            style: TextStyle(fontSize: 13, color: colors.inkMuted),
          ),
          const SizedBox(height: 8),
          AdminTable(
            headers: [
              l10n.adminCoverageArea,
              l10n.adminCoverageTechnicians,
              l10n.adminCoverageRequests,
              l10n.adminCoverageGotOffer,
              l10n.adminCoverageAds,
            ],
            flexes: const [3, 3, 2, 3, 4],
            rows: [
              for (final area in report.areas)
                AdminTableRow(
                  cells: [
                    Text(
                      area.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text('${area.verifiedTechnicians}'),
                    Text('${area.requests}'),
                    _gotOffer(area, colors, l10n),
                    _AdsPill(area: area, min: report.adsMinTechnicians),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _gotOffer(
    AreaCoverage area,
    AppColors colors,
    AppLocalizations l10n,
  ) {
    final percent = area.gotOfferPercent;
    if (percent == null) return Text(l10n.adminNone);
    return Text(
      '$percent%',
      style: percent < 80
          ? TextStyle(color: colors.danger, fontWeight: FontWeight.w700)
          : null,
    );
  }
}

class _AdsPill extends StatelessWidget {
  const _AdsPill({required this.area, required this.min});

  final AreaCoverage area;
  final int min;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!area.isOpen) {
      return StatusPill(
        label: l10n.adminAdsAreaClosed,
        tone: PillTone.neutral,
      );
    }
    return area.adsActive
        ? StatusPill(
            label: l10n.adminAdsActive,
            tone: PillTone.success,
            icon: Icons.check_rounded,
          )
        : StatusPill(
            label: l10n.adminAdsPaused(min),
            tone: PillTone.waiting,
            icon: Icons.pause_rounded,
          );
  }
}
