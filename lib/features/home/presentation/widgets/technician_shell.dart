import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/widgets/app_tab_shell.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's five main tabs.
class TechnicianShell extends StatelessWidget {
  const TechnicianShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppTabShell(
      navigationShell: navigationShell,
      tabs: [
        (icon: Icons.wb_sunny_outlined, label: l10n.navToday),
        (icon: Icons.inbox_outlined, label: l10n.navOpenRequests),
        (icon: Icons.build_outlined, label: l10n.navJobs),
        (icon: Icons.people_outline_rounded, label: l10n.navCustomers),
        (icon: Icons.account_balance_wallet_outlined, label: l10n.navMoney),
      ],
    );
  }
}
