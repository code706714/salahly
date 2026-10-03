import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// The small muted title at the top of a card on a job's screens, e.g.
/// "العميل" or "الصور".
class JobCardLabel extends StatelessWidget {
  const JobCardLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: context.appColors.inkMuted,
        ),
      ),
    );
  }
}
