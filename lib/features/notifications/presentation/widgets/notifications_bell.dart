import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/square_icon_button.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The bell that opens the notifications, with a dot while some are
/// unread.
class NotificationsBell extends StatelessWidget {
  const NotificationsBell({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final unread = context.select<NotificationsCubit, int>(
      (cubit) => cubit.state.unread,
    );
    return Stack(
      children: [
        SquareIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: unread > 0 ? l10n.notifBellUnread(unread) : l10n.notifTitle,
          onPressed: () => context.push(AppRoutes.notificationsFor(role)),
        ),
        if (unread > 0)
          PositionedDirectional(
            top: 11,
            end: 13,
            child: IgnorePointer(
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
