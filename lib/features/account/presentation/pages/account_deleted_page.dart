import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "حسابك اتمسح": shown after the account is gone and the phone is signed
/// out, worded for [honorific].
class AccountDeletedPage extends StatelessWidget {
  const AccountDeletedPage({required this.honorific, super.key});

  final String honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colors.divider,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                header: true,
                child: Text(
                  l10n.acctDeleteDoneTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.acctDeleteDoneBody(honorific),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.7,
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.inkSoft,
            foregroundColor: colors.ink,
          ),
          onPressed: () => context.go(AppRoutes.login),
          child: Text(l10n.acctDeleteDoneButton),
        ),
      ),
    );
  }
}
