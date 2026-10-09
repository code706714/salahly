import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:salahly/features/notifications/presentation/cubit/push_cubit.dart';
import 'package:salahly/features/notifications/presentation/notification_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Push for one side of the app, inside its scope: explains why before the
/// system asks for permission, shows a message that arrives while the app
/// is open, and opens the screen of one that was tapped. Needs the side's
/// [NotificationsCubit] above it.
class PushScope extends StatefulWidget {
  const PushScope({required this.role, required this.child, super.key});

  final UserRole role;
  final Widget child;

  @override
  State<PushScope> createState() => _PushScopeState();
}

class _PushScopeState extends State<PushScope> {
  late final PushCubit _push = PushCubit(context.read());

  @override
  void initState() {
    super.initState();
    unawaited(_push.start());
  }

  @override
  void dispose() {
    unawaited(_push.close());
    super.dispose();
  }

  /// The screen [notice] opens on this side, or null when it is for the
  /// other side of the app.
  String? _routeOf(PushNotice notice) => notice.role == widget.role
      ? notificationKindRoute(
          notice.kind,
          widget.role,
          requestId: notice.requestId,
        )
      : null;

  Future<void> _explain() async {
    final l10n = AppLocalizations.of(context);
    final push = _push;
    final body = switch (widget.role) {
      UserRole.consumer => l10n.pushRationaleConsumer(context.readHonorific()),
      UserRole.technician => l10n.pushRationaleTechnician,
    };
    final allowed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.pushRationaleTitle),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.pushRationaleLater),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.primary,
            ),
            child: Text(l10n.pushRationaleAllow),
          ),
        ],
      ),
    );
    if (allowed ?? false) {
      await push.allow();
    } else {
      push.later();
    }
  }

  void _show(PushNotice notice) {
    unawaited(context.read<NotificationsCubit>().load());
    final title = notice.title;
    if (title == null) return;
    final l10n = AppLocalizations.of(context);
    final route = _routeOf(notice);
    final router = GoRouter.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text([title, ?notice.body].join('\n')),
          action: route == null
              ? null
              : SnackBarAction(
                  label: l10n.pushOpen,
                  textColor: context.appColors.brassLight,
                  onPressed: () => unawaited(router.push(route)),
                ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _push,
      child: MultiBlocListener(
        listeners: [
          BlocListener<PushCubit, PushState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == PushStatus.needsPermission,
            listener: (context, state) => unawaited(_explain()),
          ),
          BlocListener<PushCubit, PushState>(
            listenWhen: (previous, current) =>
                previous.received != current.received &&
                current.received != null,
            listener: (context, state) => _show(state.received!.notice),
          ),
          BlocListener<PushCubit, PushState>(
            listenWhen: (previous, current) =>
                previous.opened != current.opened && current.opened != null,
            listener: (context, state) {
              final notice = state.opened!.notice;
              unawaited(context.read<NotificationsCubit>().load());
              final route = _routeOf(notice);
              if (route != null) unawaited(context.push(route));
            },
          ),
        ],
        child: widget.child,
      ),
    );
  }
}
