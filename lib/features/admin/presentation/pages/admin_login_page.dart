import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_gate_card.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_otp_flow.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Signs the team in with a phone number and a code. Whether the number
/// belongs to an admin is for the server to say, once they are in.
class AdminLoginPage extends StatelessWidget {
  const AdminLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return AdminGateCard(
      children: [
        Text(l10n.adminLoginTitle, style: textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          l10n.adminLoginSubtitle,
          style: textTheme.bodyLarge?.copyWith(
            color: context.appColors.inkMuted,
          ),
        ),
        const SizedBox(height: 24),
        const AdminOtpFlow(),
      ],
    );
  }
}
