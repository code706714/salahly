import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/brand_mark.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The console's frame: the menu on the side and the page beside it.
///
/// The console is made for a desktop screen. Narrower than [minWidth] it
/// scrolls sideways instead of squeezing the page.
class AdminShell extends StatelessWidget {
  const AdminShell({required this.child, super.key});

  static const minWidth = 1100.0;
  static const menuWidth = 248.0;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final frame = SizedBox(
            width: constraints.maxWidth < minWidth
                ? minWidth
                : constraints.maxWidth,
            height: constraints.maxHeight,
            child: Row(
              children: [
                const _Menu(),
                Expanded(child: child),
              ],
            ),
          );
          return constraints.maxWidth < minWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: frame,
                )
              : frame;
        },
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final path = GoRouterState.of(context).uri.path;
    final overview = context.select<OverviewCubit, AdminOverview?>(
      (cubit) => cubit.state.overview,
    );
    final items = [
      (
        AdminRoutes.overview,
        Icons.grid_view_rounded,
        l10n.adminNavOverview,
        0,
      ),
      (
        AdminRoutes.verification,
        Icons.badge_outlined,
        l10n.adminNavVerification,
        overview?.pendingVerifications.count ?? 0,
      ),
      (
        AdminRoutes.requests,
        Icons.format_list_bulleted_rounded,
        l10n.adminNavRequests,
        overview?.openComplaints.count ?? 0,
      ),
      (
        AdminRoutes.transfers,
        Icons.account_balance_wallet_outlined,
        l10n.adminNavTransfers,
        overview?.pendingTopups.count ?? 0,
      ),
      (
        AdminRoutes.users,
        Icons.groups_outlined,
        l10n.adminNavUsers,
        0,
      ),
      (
        AdminRoutes.settings,
        Icons.settings_outlined,
        l10n.adminNavSettings,
        0,
      ),
      (
        AdminRoutes.audit,
        Icons.history_rounded,
        l10n.adminNavAudit,
        0,
      ),
    ];
    return Container(
      width: AdminShell.menuWidth,
      color: colors.ink,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 20),
            child: Row(
              children: [
                const BrandMark(size: 36, radius: 10),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.surface,
                        ),
                      ),
                      Text(
                        l10n.adminTeamPanel,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final (route, icon, label, badge) in items) ...[
            _MenuItem(
              icon: icon,
              label: label,
              badge: badge,
              selected: path == route || path.startsWith('$route/'),
              onTap: () => context.go(route),
            ),
            const SizedBox(height: 4),
          ],
          const Spacer(),
          _MenuItem(
            icon: Icons.logout_rounded,
            label: l10n.adminSignOut,
            onTap: () => context.read<AdminSessionCubit>().signOut(),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final foreground = selected ? colors.ink : colors.onInkMuted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.background : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.sm),
          hoverColor: Color.lerp(colors.ink, colors.surface, 0.1),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: foreground,
                      ),
                    ),
                  ),
                  if (badge > 0) _Badge(badge),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: colors.onPrimary,
        ),
      ),
    );
  }
}
