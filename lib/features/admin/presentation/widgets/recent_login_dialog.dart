import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_otp_flow.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks the admin to sign in again with a code, which money and price
/// changes need (the server wants a sign in from the last 15 minutes).
/// Resolves to true once they did, so the change can be repeated.
Future<bool> showRecentLoginDialog(BuildContext context) async {
  final signedInAgain = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _RecentLoginDialog(),
  );
  return signedInAgain ?? false;
}

class _RecentLoginDialog extends StatelessWidget {
  const _RecentLoginDialog();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final phone = PhoneNumber.tryParse(
      context.read<AuthRepository>().currentUser?.phone ?? '',
    );
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(
        l10n.adminReloginTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                phone == null
                    ? l10n.adminReloginNoPhone
                    // Isolated so the number keeps its left-to-right order.
                    : l10n.adminReloginBody('\u2066${phone.local}\u2069'),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: colors.inkMuted,
                ),
              ),
              if (phone != null) ...[
                const SizedBox(height: 16),
                AdminOtpFlow(
                  fixedPhone: phone,
                  onVerified: () => Navigator.of(context).pop(true),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.adminReloginCancel),
        ),
        if (phone == null)
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(false);
              unawaited(context.read<AdminSessionCubit>().signOut());
            },
            child: Text(l10n.adminReloginSignOut),
          ),
      ],
    );
  }
}
