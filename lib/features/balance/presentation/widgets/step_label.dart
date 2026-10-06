import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// A step's number in a dark circle and its question.
class StepLabel extends StatelessWidget {
  const StepLabel({required this.number, required this.label, super.key});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      header: true,
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.background,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
