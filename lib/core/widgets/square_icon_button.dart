import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// A 48x48 rounded-square icon button, e.g. call, calendar or search.
///
/// Outlined on the surface color by default; a [background] makes it a
/// filled tile without a border.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.background,
    this.foreground,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final filled = background != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: filled
              ? BorderSide.none
              : BorderSide(color: colors.border, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icon, size: 24, color: foreground ?? colors.ink),
          ),
        ),
      ),
    );
  }
}
