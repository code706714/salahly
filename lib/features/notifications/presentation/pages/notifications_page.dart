import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:salahly/features/notifications/presentation/notification_labels.dart';
import 'package:salahly/features/notifications/presentation/widgets/notification_tile.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What happened on [role]'s side of the app, newest first. The list is
/// shared with the bell and fetched again on opening.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({required this.role, super.key});

  final UserRole role;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<NotificationsCubit>().load());
  }

  @override
  Widget build(BuildContext context) => NotificationsView(role: widget.role);
}

class NotificationsView extends StatelessWidget {
  const NotificationsView({required this.role, super.key});

  final UserRole role;

  /// A consumer's copy is gendered; a technician's is masculine.
  String _honorific(BuildContext context) =>
      role == UserRole.consumer ? context.watchHonorific() : 'other';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NotificationsCubit>();
    final state = context.watch<NotificationsCubit>().state;
    final honorific = _honorific(context);

    return Scaffold(
      appBar: DetailHeader(
        title: l10n.notifTitle,
        trailing: state.unread > 0
            ? TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: context.appColors.primary,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => unawaited(cubit.markAllRead()),
                child: Text(l10n.notifMarkAllRead),
              )
            : null,
      ),
      body: switch (state.status) {
        NotificationsStatus.loading when state.notifications.isEmpty =>
          const Center(child: CircularProgressIndicator()),
        NotificationsStatus.failed when state.notifications.isEmpty =>
          _LoadFailed(
            message: _failureMessage(
              l10n,
              state.failure,
              role: role,
              honorific: honorific,
            ),
            retry: role == UserRole.consumer
                ? l10n.consumerRetry(honorific)
                : l10n.retry,
            onRetry: cubit.load,
          ),
        _ => RefreshIndicator(
          onRefresh: cubit.load,
          child: state.notifications.isEmpty
              ? _Empty(honorific: honorific)
              : _List(
                  role: role,
                  honorific: honorific,
                  notifications: state.notifications,
                ),
        ),
      },
    );
  }
}

String _failureMessage(
  AppLocalizations l10n,
  Failure? failure, {
  required UserRole role,
  required String honorific,
}) {
  final cause = failure ?? const UnexpectedFailure();
  return switch (role) {
    UserRole.consumer => consumerFailureMessage(
      l10n,
      cause,
      honorific: honorific,
    ),
    UserRole.technician => commonFailureMessage(l10n, cause),
  };
}

class _List extends StatelessWidget {
  const _List({
    required this.role,
    required this.honorific,
    required this.notifications,
  });

  final UserRole role;
  final String honorific;
  final List<AppNotification> notifications;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final categories = context.watch<CategoriesCubit>().state;
    final areas = context.watch<AreasCubit>().state;
    final cubit = context.read<NotificationsCubit>();
    final now = DateTime.now();

    final children = <Widget>[];
    String? heading;
    for (final notification in notifications) {
      final next = notificationDayHeading(
        l10n,
        notification.createdAt,
        now: now,
      );
      if (next != heading) {
        heading = next;
        children.add(_Heading(next));
      }
      final text = notificationText(
        l10n,
        notification,
        role: role,
        honorific: honorific,
        today: now,
        categoryName: categories.category(notification.categoryId)?.name,
        areaName: areas.nameOf(notification.areaId),
      );
      children.add(
        NotificationTile(
          notification: notification,
          title: text.title,
          body: text.body,
          time: notificationTimeLabel(l10n, notification.createdAt, now: now),
          onTap: () {
            unawaited(cubit.markRead(notification.id));
            unawaited(context.push(notificationRoute(notification, role)));
          },
        ),
      );
    }
    return ColoredBox(
      color: colors.surface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.appColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.honorific});

  final String honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 96, 32, 24),
      children: [
        Icon(
          Icons.notifications_none_rounded,
          size: 48,
          color: colors.dashedBorder,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.notifEmptyTitle(honorific),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.notifEmptyBody(honorific),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
        ),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({
    required this.message,
    required this.retry,
    required this.onRetry,
  });

  final String message;
  final String retry;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => unawaited(onRetry()),
              child: Text(retry),
            ),
          ],
        ),
      ),
    );
  }
}
