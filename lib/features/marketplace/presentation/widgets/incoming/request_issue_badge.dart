import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/catalog/presentation/category_icon.dart';

/// The request's trade as an icon on a tinted square.
class RequestIssueBadge extends StatelessWidget {
  const RequestIssueBadge({required this.categoryId, super.key});

  final String categoryId;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Icon(categoryIcon(categoryId), size: 24, color: colors.primary),
    );
  }
}
