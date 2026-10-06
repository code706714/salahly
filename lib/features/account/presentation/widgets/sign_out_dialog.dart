import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks before signing out. Resolves to true to sign out.
///
/// Signing out deletes what is on a technician's phone, so it warns while
/// [sync] still has changes the server hasn't got. The dialog opens above
/// the technician screens, so [sync] is handed over rather than read from
/// its context. A consumer has nothing waiting on the phone: they pass no
/// [sync], and their [honorific] picks the copy's grammar.
Future<bool> showSignOutDialog(
  BuildContext context, {
  SyncCubit? sync,
  String? honorific,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => sync == null
        ? _SignOutDialog(unsent: 0, honorific: honorific)
        : BlocProvider.value(
            value: sync,
            child: BlocSelector<SyncCubit, SyncState, int>(
              selector: (state) => state.pendingChanges,
              builder: (context, unsent) =>
                  _SignOutDialog(unsent: unsent, honorific: honorific),
            ),
          ),
  );
  return confirmed ?? false;
}

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog({required this.unsent, required this.honorific});

  /// Changes the server hasn't got yet.
  final int unsent;

  /// The consumer's honorific; null for a technician.
  final String? honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = this.honorific;
    final warns = unsent > 0;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(
        honorific == null
            ? l10n.accountSignOutTitle
            : l10n.consumerAccountSignOutTitle(honorific),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: Text(
        warns
            ? l10n.accountSignOutUnsent(unsent)
            : honorific == null
            ? l10n.accountSignOutBody
            : l10n.consumerAccountSignOutBody(honorific),
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
          child: Text(
            honorific == null
                ? l10n.signOut
                : l10n.consumerAccountSignOut(honorific),
          ),
        ),
      ],
    );
  }
}
