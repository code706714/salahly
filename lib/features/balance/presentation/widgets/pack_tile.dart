import 'package:flutter/material.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A pack to pick: what it gives, what one use costs in it and what it
/// saves, and its price.
class PackTile extends StatelessWidget {
  const PackTile({
    required this.pack,
    required this.role,
    required this.honorific,
    required this.selected,
    required this.onTap,
    this.singlePricePiastres,
    super.key,
  });

  final CreditPack pack;
  final UserRole role;
  final String honorific;
  final bool selected;
  final VoidCallback onTap;

  /// What one use costs bought alone, to show what the pack saves.
  final int? singlePricePiastres;

  String _name(AppLocalizations l10n) => switch (role) {
    UserRole.consumer => l10n.buyUsesPackConsumer(pack.uses),
    UserRole.technician => l10n.buyUsesPackTechnician(pack.uses),
  };

  String _note(AppLocalizations l10n) {
    if (pack.uses == 1) {
      return switch (role) {
        UserRole.consumer => l10n.buyUsesNoteSingleConsumer,
        UserRole.technician => l10n.buyUsesNoteSingleTechnician,
      };
    }
    final perUse = formatPounds(pack.perUsePiastres);
    final saved = singlePricePiastres == null
        ? 0
        : pack.savingsAgainst(singlePricePiastres!);
    if (saved == 0) {
      return switch (role) {
        UserRole.consumer => l10n.buyUsesNotePerUseConsumer(perUse),
        UserRole.technician => l10n.buyUsesNotePerUseTechnician(perUse),
      };
    }
    return switch (role) {
      UserRole.consumer => l10n.buyUsesNoteSavingConsumer(
        honorific,
        perUse,
        formatPounds(saved),
      ),
      UserRole.technician => l10n.buyUsesNoteSavingTechnician(
        perUse,
        formatPounds(saved),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final edge = selected ? colors.primary : colors.border;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: AppCard(
        radius: AppRadii.lg,
        color: selected ? colors.selectedTint : colors.surface,
        borderColor: edge,
        borderWidth: 2,
        padding: const EdgeInsets.all(14),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: edge, width: 2),
              ),
              child: selected
                  ? Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name(l10n),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _note(l10n),
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.pounds(formatPounds(pack.pricePiastres)),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
