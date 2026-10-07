import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_actions_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/add_area_dialog.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/settings_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The areas the platform serves, with how well each is covered, a switch to
/// close or open each for new requests, and a way to add one.
///
/// Unlike the rest of the page, an area is saved the moment it changes.
class AreasCard extends StatelessWidget {
  const AreasCard({required this.report, super.key});

  final AreaCoverageReport report;

  Future<void> _toggle(
    BuildContext context,
    AreaCoverage area, {
    required bool isOpen,
  }) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsActionsCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: isOpen
          ? l10n.adminSettingsAreaOpenTitle(area.name)
          : l10n.adminSettingsAreaCloseTitle(area.name),
      body: isOpen
          ? l10n.adminSettingsAreaOpenBody
          : l10n.adminSettingsAreaCloseBody,
      confirmLabel: isOpen
          ? l10n.adminSettingsAreaOpenConfirm
          : l10n.adminSettingsAreaCloseConfirm,
      destructive: !isOpen,
    );
    if (confirmed) await cubit.setAreaOpen(area.id, isOpen: isOpen);
  }

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<SettingsActionsCubit>();
    final area = await showAddAreaDialog(
      context,
      existingIds: {for (final area in report.areas) area.id},
    );
    if (area != null) await cubit.saveArea(area);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBusy = context.select<SettingsActionsCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    return SettingsCard(
      title: l10n.adminSettingsAreasTitle,
      note: l10n.adminSettingsAreasHint(report.adsMinTechnicians),
      trailing: TextButton(
        onPressed: isBusy ? null : () => _add(context),
        child: Text(l10n.adminSettingsAddArea),
      ),
      child: AdminTable(
        headers: [
          l10n.adminCoverageArea,
          l10n.adminCoverageTechnicians,
          l10n.adminCoverageRequests,
          l10n.adminCoverageAds,
          l10n.adminSettingsAreaOpen,
        ],
        flexes: const [4, 3, 2, 4, 3],
        rows: [
          for (final area in report.areas)
            AdminTableRow(
              cells: [
                Text(
                  '${area.name} · ${area.city}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text('${area.verifiedTechnicians}'),
                Text('${area.requests}'),
                _ads(l10n, area, report.adsMinTechnicians),
                Switch(
                  value: area.isOpen,
                  onChanged: isBusy
                      ? null
                      : (isOpen) => _toggle(context, area, isOpen: isOpen),
                ),
              ],
            ),
        ],
      ),
    );
  }

  static Widget _ads(AppLocalizations l10n, AreaCoverage area, int min) {
    if (!area.isOpen) {
      return StatusPill(
        label: l10n.adminAdsAreaClosed,
        tone: PillTone.neutral,
      );
    }
    return area.adsActive
        ? StatusPill(label: l10n.adminAdsActive, tone: PillTone.success)
        : StatusPill(
            label: l10n.adminAdsPausedShort(
              (min - area.verifiedTechnicians).clamp(0, min),
            ),
            tone: PillTone.waiting,
          );
  }
}
