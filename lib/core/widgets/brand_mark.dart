import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// The wrench logo on the brand color square.
class BrandMark extends StatelessWidget {
  const BrandMark({required this.size, required this.radius, super.key});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.build_rounded,
        color: colors.onPrimary,
        size: size * 0.55,
      ),
    );
  }
}
