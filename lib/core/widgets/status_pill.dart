import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// What a pill tells at a glance, which sets its colors.
enum PillTone {
  /// Done or agreed: confirmed, finished, paid.
  success,

  /// Waiting on someone: money due, a quote with no answer.
  waiting,

  /// Needs the technician: not confirmed yet.
  attention,

  /// Late.
  danger,

  /// A label rather than a state, e.g. from the platform.
  dark,

  /// Over without a result: cancelled or expired.
  neutral,
}

/// A small rounded label for a status, e.g. "اتأكد" or "متأخر 12 يوم".
class StatusPill extends StatelessWidget {
  const StatusPill({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final (background, foreground) = switch (tone) {
      PillTone.success => (colors.successSoft, colors.success),
      PillTone.waiting => (colors.warningSoft, colors.warning),
      PillTone.attention => (colors.primarySoft, colors.primaryPressed),
      PillTone.danger => (colors.dangerSoft, colors.dangerDeep),
      PillTone.dark => (colors.ink, colors.surface),
      PillTone.neutral => (colors.divider, colors.inkQuiet),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
