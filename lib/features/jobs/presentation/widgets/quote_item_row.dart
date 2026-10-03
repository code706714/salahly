import 'package:flutter/material.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One line of a quote: what it is, its total, and a stepper for how many.
/// At one, the minus button removes the line.
class QuoteItemRow extends StatelessWidget {
  const QuoteItemRow({
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
    super.key,
  });

  final JobItemDraft item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatPounds(item.totalPiastres),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.quoteUnitPrice(
                      item.quantity,
                      formatPounds(item.unitPricePiastres),
                    ),
                    style: TextStyle(fontSize: 14, color: colors.inkMuted),
                  ),
                ),
                _StepButton(
                  icon: Icons.add_rounded,
                  tooltip: l10n.quoteIncrease,
                  onPressed: item.quantity < JobItem.maxQuantity
                      ? onIncrement
                      : null,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 28),
                  child: Text(
                    '${item.quantity}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                if (item.quantity > 1)
                  _StepButton(
                    icon: Icons.remove_rounded,
                    tooltip: l10n.quoteDecrease,
                    onPressed: onDecrement,
                  )
                else
                  _StepButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: l10n.quoteRemoveItem,
                    onPressed: onRemove,
                    color: colors.danger,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A 44 square outlined button with a 48 square tap area.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(44),
        minimumSize: const Size.square(44),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
        foregroundColor: color ?? colors.ink,
        backgroundColor: colors.surface,
        disabledBackgroundColor: colors.surface,
        side: BorderSide(color: colors.fieldBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
    );
  }
}
