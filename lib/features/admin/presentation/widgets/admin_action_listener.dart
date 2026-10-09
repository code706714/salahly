import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/recent_login_dialog.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Reacts to what happens to the admin's changes: says what a change did,
/// explains one the server refused, and when it needs a fresh sign in, asks
/// for one and repeats the change.
///
/// [onChanged] runs when the server's data changed, so the page can load it
/// again.
class AdminActionListener<C extends ActionCubit> extends StatelessWidget {
  const AdminActionListener({
    required this.onChanged,
    required this.child,
    super.key,
  });

  final VoidCallback onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<C, ActionState>(
      listenWhen: (previous, current) =>
          current.completed != previous.completed ||
          (current.failure != null && current.failure != previous.failure),
      listener: (context, state) {
        final l10n = AppLocalizations.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final cubit = context.read<C>();
        final failure = state.failure;
        if (failure == null) {
          onChanged();
          if (state.outcome case final outcome?) {
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(_outcomeMessage(l10n, outcome))),
              );
          }
          return;
        }
        if (failure is RecentLoginRequiredFailure) {
          unawaited(_signInAgainAndRetry(context, cubit));
          return;
        }
        cubit.dismissFailure();
        // What was reviewed is not what the server has any more.
        if (failure is NotPendingFailure || failure is AdminNotFoundFailure) {
          onChanged();
        }
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(adminFailureMessage(l10n, failure))),
          );
      },
      child: child,
    );
  }

  static Future<void> _signInAgainAndRetry(
    BuildContext context,
    ActionCubit cubit,
  ) async {
    cubit.dismissFailure();
    final signedInAgain = await showRecentLoginDialog(context);
    if (signedInAgain) await cubit.retry();
  }

  static String _outcomeMessage(AppLocalizations l10n, AdminOutcome outcome) =>
      switch (outcome) {
        AdminOutcome.verificationApproved => l10n.adminVerifyApproved,
        AdminOutcome.verificationRejected => l10n.adminVerifyRejected,
        AdminOutcome.topupApproved => l10n.adminTopupsApproved,
        AdminOutcome.topupRejected => l10n.adminTopupsRejected,
        AdminOutcome.complaintResolved => l10n.adminComplaintClosed,
        AdminOutcome.userSuspended => l10n.adminSuspended,
        AdminOutcome.userRestored => l10n.adminUsersRestored,
        AdminOutcome.settingsSaved => l10n.adminSettingsSaved,
        AdminOutcome.packAdded => l10n.adminSettingsPackSaved,
        AdminOutcome.areaSaved => l10n.adminSettingsAreaSaved,
      };
}
