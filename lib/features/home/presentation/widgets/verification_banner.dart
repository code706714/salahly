import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where the technician's ID check stands, until it is approved. Takes no
/// space once approved, [padding] included.
class VerificationBanner extends StatelessWidget {
  const VerificationBanner({
    required this.status,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final VerificationStatus? status;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final (icon, background, foreground, title, body) = switch (status) {
      VerificationStatus.pending => (
        Icons.schedule_rounded,
        colors.warningSoft,
        colors.warning,
        l10n.techPendingTitle,
        l10n.techPendingBody,
      ),
      VerificationStatus.rejected => (
        Icons.error_outline_rounded,
        colors.primarySoft,
        colors.primaryPressed,
        l10n.techRejectedTitle,
        l10n.techRejectedBody,
      ),
      _ => (null, null, null, null, null),
    };
    if (icon == null) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: foreground,
                    fontSize: 14,
                    height: 1.6,
                  ),
                  children: [
                    TextSpan(
                      text: '$title\n',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(text: body),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
