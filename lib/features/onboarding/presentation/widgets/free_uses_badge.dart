import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// A rounded square with the number of free uses, e.g. "2".
class FreeUsesBadge extends StatelessWidget {
  const FreeUsesBadge({
    required this.count,
    required this.background,
    required this.foreground,
    super.key,
  });

  final int count;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
