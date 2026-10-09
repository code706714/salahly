import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// A toggleable chip: outlined when off, brand-tinted when on.
class ChoiceChipButton extends StatelessWidget {
  const ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.inkWhenSelected = false,
    this.fontSize = 15,
    this.minHeight = 44,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    super.key,
  });

  final String label;
  final bool selected;

  /// Null makes the chip read-only; unselected read-only chips show as
  /// unavailable.
  final VoidCallback? onTap;
  final IconData? icon;

  /// Keeps the label in the ink color when selected, instead of the brand's.
  final bool inkWhenSelected;
  final double fontSize;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  static const _borderWidth = 1.5;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected && !inkWhenSelected
        ? colors.primaryPressed
        : colors.ink;
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null && !selected ? 0.6 : 1,
        child: Material(
          color: selected ? colors.primarySoft : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            side: BorderSide(
              color: selected ? colors.primary : colors.fieldBorder,
              width: _borderWidth,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Padding(
                // The border takes room from the chip.
                padding: padding.add(const EdgeInsets.all(_borderWidth)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: foreground),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: foreground,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
