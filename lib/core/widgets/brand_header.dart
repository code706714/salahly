import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/brand_mark.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Dark header with the logo, a title and a short explanation, used on the
/// screens people see before they have an account.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    required this.title,
    required this.subtitle,
    this.titleSize = 28,
    this.bottomPadding = 40,
    super.key,
  });

  final String title;
  final String subtitle;
  final double titleSize;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      color: colors.ink,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        MediaQuery.paddingOf(context).top + AppSpacing.md,
        AppSpacing.xl,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 40, radius: AppRadii.sm),
              const SizedBox(width: 10),
              Text(
                AppLocalizations.of(context).appName,
                style: TextStyle(
                  color: colors.background,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            style: TextStyle(
              color: colors.background,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(
              color: colors.onInkMuted,
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
