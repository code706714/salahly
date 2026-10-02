import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's four main tabs with the bottom navigation.
class TechnicianShell extends StatelessWidget {
  const TechnicianShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final tabs = [
      (Icons.wb_sunny_outlined, l10n.navToday),
      (Icons.build_outlined, l10n.navJobs),
      (Icons.people_outline_rounded, l10n.navCustomers),
      (Icons.account_balance_wallet_outlined, l10n.navMoney),
    ];
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                for (final (index, (icon, label)) in tabs.indexed)
                  Expanded(
                    child: _Tab(
                      icon: icon,
                      label: label,
                      selected: index == navigationShell.currentIndex,
                      onTap: () => navigationShell.goBranch(
                        index,
                        // Tapping the open tab goes back to its start.
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = selected ? colors.primary : colors.inkMuted;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
