import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/widgets/app_tab_shell.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumer's four main tabs.
class ConsumerShell extends StatelessWidget {
  const ConsumerShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppTabShell(
      navigationShell: navigationShell,
      tabs: [
        (icon: Icons.home_outlined, label: l10n.navHome),
        (icon: Icons.groups_outlined, label: l10n.navTechnicians),
        (icon: Icons.format_list_bulleted_rounded, label: l10n.navMyRequests),
        (icon: Icons.person_outline_rounded, label: l10n.navMyAccount),
      ],
    );
  }
}
