import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// The strip at the bottom of a pushed screen that holds its main action.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // A container, so the border adds to the height as in the design.
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: child,
        ),
      ),
    );
  }
}
