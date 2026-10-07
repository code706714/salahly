import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_gate_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Shown while the saved session is restored and the server says whether
/// it belongs to an admin.
class AdminCheckingPage extends StatelessWidget {
  const AdminCheckingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminGateCard(
      children: [
        const Center(child: CircularProgressIndicator()),
        const SizedBox(height: 16),
        Text(
          l10n.adminChecking,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.appColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
