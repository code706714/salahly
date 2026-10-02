import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/money/presentation/money_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Lets the technician pick one of [months], with [selected] checked.
/// Resolves to null if dismissed.
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required List<DateTime> months,
  required DateTime selected,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      final colors = context.appColors;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.moneyMonthsTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              itemCount: months.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final month = months[index];
                final isSelected = month == selected;
                return ListTile(
                  minTileHeight: 56,
                  selected: isSelected,
                  title: Text(
                    monthYear(month),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: colors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(month),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
