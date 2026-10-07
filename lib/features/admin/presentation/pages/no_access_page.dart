import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_gate_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Shown to someone the server does not accept as an admin. They are
/// already signed out.
class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    return AdminGateCard(
      children: [
        Icon(Icons.lock_outline_rounded, size: 40, color: colors.danger),
        const SizedBox(height: 12),
        Text(
          l10n.adminNoAccessTitle,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.adminNoAccessBody,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: context.read<AdminSessionCubit>().leaveNoAccess,
          child: Text(l10n.adminNoAccessBack),
        ),
      ],
    );
  }
}
