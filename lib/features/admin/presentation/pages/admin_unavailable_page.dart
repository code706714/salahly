import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_gate_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Shown when the server could not be asked who is signed in, with a way
/// to ask again or to sign out.
class AdminUnavailablePage extends StatelessWidget {
  const AdminUnavailablePage({required this.failure, super.key});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final session = context.read<AdminSessionCubit>();
    return AdminGateCard(
      children: [
        Text(
          l10n.adminUnavailableTitle,
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          adminFailureMessage(l10n, failure),
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: session.retry, child: Text(l10n.retry)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: session.signOut,
          child: Text(l10n.adminSignOut),
        ),
      ],
    );
  }
}
