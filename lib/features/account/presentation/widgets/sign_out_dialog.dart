import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks before signing out. Signing out deletes what is on the phone, so it
/// warns while [sync] still has changes the server hasn't got. Resolves to
/// true to sign out.
///
/// The dialog opens above the technician screens, so [sync] is handed over
/// rather than read from its context.
Future<bool> showSignOutDialog(
  BuildContext context, {
  required SyncCubit sync,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) =>
        BlocProvider.value(value: sync, child: const _SignOutDialog()),
  );
  return confirmed ?? false;
}

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final unsent = context.select<SyncCubit, int>(
      (cubit) => cubit.state.pendingChanges,
    );
    final warns = unsent > 0;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(
        l10n.accountSignOutTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: Text(
        warns ? l10n.accountSignOutUnsent(unsent) : l10n.accountSignOutBody,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: warns ? colors.danger : colors.inkMuted,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.accountSignOutStay),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: warns ? colors.danger : colors.primary,
          ),
          child: Text(l10n.signOut),
        ),
      ],
    );
  }
}
