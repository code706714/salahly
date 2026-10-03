import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// A section's title with an optional note at the end, e.g. a count.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.note, super.key});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final note = this.note;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: colors.ink,
              ),
            ),
          ),
        ),
        if (note != null)
          Text(note, style: TextStyle(fontSize: 14, color: colors.inkMuted)),
      ],
    );
  }
}
