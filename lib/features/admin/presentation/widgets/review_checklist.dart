import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// The checks a reviewer ticks before approving. The reviewer's ticks are
/// kept by the caller, which enables the approve button once all are ticked;
/// they are a reminder to look, not something the server checks.
class ReviewChecklist extends StatelessWidget {
  const ReviewChecklist({
    required this.title,
    required this.labels,
    required this.checked,
    required this.onToggle,
    super.key,
  });

  final String title;
  final List<String> labels;

  /// The indexes of [labels] that are ticked.
  final Set<int> checked;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: colors.background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: CheckboxListTile(
              value: checked.contains(i),
              onChanged: (_) => onToggle(i),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: colors.successBright,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              title: Text(labels[i], style: const TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ],
    );
  }
}
