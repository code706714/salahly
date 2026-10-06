import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/account/presentation/cubit/delete_account_cubit.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Explains what deleting goes and what stays, and deletes after the
/// person confirms. Signs out once the account is gone.
class DeleteAccountPage extends StatelessWidget {
  const DeleteAccountPage({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DeleteAccountCubit(context.read()),
      child: DeleteAccountView(role: role),
    );
  }
}

class DeleteAccountView extends StatefulWidget {
  const DeleteAccountView({required this.role, super.key});

  final UserRole role;

  @override
  State<DeleteAccountView> createState() => _DeleteAccountViewState();
}

class _DeleteAccountViewState extends State<DeleteAccountView> {
  bool _understood = false;

  bool get _isConsumer => widget.role == UserRole.consumer;

  /// Back to where the person came from; the account tab when nothing is
  /// behind this screen (after signing in again).
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(
        _isConsumer ? AppRoutes.consumerAccount : AppRoutes.technicianAccount,
      );
    }
  }

  /// A consumer's copy is gendered; a technician's is masculine.
  String _honorific(BuildContext context, {bool watch = true}) {
    if (!_isConsumer) return 'other';
    return watch ? context.watchHonorific() : context.readHonorific();
  }

  void _onState(BuildContext context, DeleteAccountState state) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case DeleteAccountStatus.deleted:
        final session = context.read<SessionCubit>();
        final honorific = _honorific(context, watch: false);
        context.go(AppRoutes.accountDeletedFor(honorific));
        unawaited(session.signOutDeleted());
      case DeleteAccountStatus.failed
          when state.failure is RecentLoginRequiredFailure:
        unawaited(_offerSignIn(context));
      case DeleteAccountStatus.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _failureMessage(
                l10n,
                state.failure,
                _honorific(context, watch: false),
              ),
            ),
          ),
        );
      case DeleteAccountStatus.idle || DeleteAccountStatus.deleting:
        break;
    }
  }

  /// Deleting needs a recent sign-in: offers to sign out and sign in again
  /// with a new code, and comes back to this screen after.
  Future<void> _offerSignIn(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = _honorific(context, watch: false);
    final session = context.read<SessionCubit>();
    final location = AppRoutes.deleteAccountFor(widget.role);
    final signOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.acctDeleteRelogTitle(honorific)),
        content: Text(l10n.acctDeleteRelogBody(honorific)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.acctDeleteRelogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.acctDeleteRelogButton(honorific)),
          ),
        ],
      ),
    );
    if (signOut ?? false) {
      try {
        await session.signOutAndReturnTo(location);
      } on Object {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.errorUnexpected)));
        }
      }
    }
  }

  String _failureMessage(
    AppLocalizations l10n,
    Failure? failure,
    String honorific,
  ) => switch (failure) {
    PendingTransferFailure() => l10n.acctDeleteTopupPending(honorific),
    final cause? when _isConsumer => consumerFailureMessage(
      l10n,
      cause,
      honorific: honorific,
    ),
    final cause? => commonFailureMessage(l10n, cause),
    null => l10n.errorUnexpected,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = _honorific(context);
    final busy = context.select<DeleteAccountCubit, bool>(
      (cubit) => cubit.state.status == DeleteAccountStatus.deleting,
    );
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    final uses = _isConsumer
        ? profile?.consumer?.requestCredits
        : profile?.technician?.jobCredits;

    return BlocListener<DeleteAccountCubit, DeleteAccountState>(
      listener: _onState,
      child: PopScope(
        canPop: !busy,
        child: Scaffold(
          appBar: DetailHeader(title: l10n.acctDeleteTitle),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.acctDeleteHeading(honorific),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.acctDeleteGoes,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final line in [
                      if (_isConsumer)
                        l10n.acctDeleteConsumerData(honorific)
                      else
                        l10n.acctDeleteTechnicianData,
                      if (uses != null)
                        if (_isConsumer)
                          l10n.acctDeleteConsumerBalance(uses)
                        else
                          l10n.acctDeleteTechnicianBalance(uses),
                      if (_isConsumer)
                        l10n.acctDeleteConsumerHistory
                      else
                        l10n.acctDeleteTechnicianHistory,
                    ]) ...[
                      const SizedBox(height: 10),
                      _GoesLine(line),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.inkSoft,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 22,
                      color: colors.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isConsumer
                            ? l10n.acctDeleteConsumerNote(honorific)
                            : l10n.acctDeleteTechnicianNote,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: busy
                    ? null
                    : () => setState(() => _understood = !_understood),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _understood,
                        activeColor: colors.danger,
                        onChanged: busy
                            ? null
                            : (value) =>
                                  setState(() => _understood = value ?? false),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.acctDeleteConfirm(honorific),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.danger,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.border,
                      disabledForegroundColor: colors.inkMuted,
                    ),
                    onPressed: _understood && !busy
                        ? () => context.read<DeleteAccountCubit>().delete()
                        : null,
                    child: busy
                        ? SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.onPrimary,
                            ),
                          )
                        : Text(l10n.acctDeleteButton),
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : () => _leave(context),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: colors.ink,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.acctDeleteKeep),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoesLine extends StatelessWidget {
  const _GoesLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.close_rounded, size: 22, color: colors.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ),
      ],
    );
  }
}
