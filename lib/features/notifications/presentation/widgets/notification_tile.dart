import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';

/// One notification: an icon tile for its kind, the text, and when it
/// happened. Unread ones are tinted.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    required this.notification,
    required this.title,
    required this.time,
    required this.onTap,
    this.body,
    super.key,
  });

  final AppNotification notification;
  final String title;
  final String? body;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final body = this.body;
    final (icon, background, foreground) = _look(notification.kind, colors);
    return Material(
      color: notification.isRead ? colors.surface : colors.attentionRow,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.divider)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, size: 22, color: foreground),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                          color: colors.ink,
                        ),
                      ),
                      if (body != null)
                        Text(
                          body,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: colors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static (IconData, Color, Color) _look(
    NotificationKind kind,
    AppColors colors,
  ) => switch (kind) {
    NotificationKind.offerReceived => (
      Icons.description_outlined,
      colors.successSoft,
      colors.success,
    ),
    NotificationKind.jobConfirmed ||
    NotificationKind.offerPicked ||
    NotificationKind.topupApproved => (
      Icons.check_rounded,
      colors.successSoft,
      colors.success,
    ),
    NotificationKind.jobStarted => (
      Icons.build_outlined,
      colors.primarySoft,
      colors.primary,
    ),
    NotificationKind.jobFinished => (
      Icons.star_rounded,
      colors.warningSoft,
      colors.brass,
    ),
    NotificationKind.priceChange => (
      Icons.warning_amber_rounded,
      colors.primarySoft,
      colors.primary,
    ),
    NotificationKind.requestCancelledByTechnician ||
    NotificationKind.requestCancelledByConsumer ||
    NotificationKind.topupRejected => (
      Icons.close_rounded,
      colors.dangerSoft,
      colors.dangerDeep,
    ),
    NotificationKind.requestExpired => (
      Icons.schedule_rounded,
      colors.inkSoft,
      colors.ink,
    ),
    NotificationKind.newRequest => (
      Icons.ac_unit_rounded,
      colors.primarySoft,
      colors.primary,
    ),
    NotificationKind.offerNotPicked => (
      Icons.person_outline_rounded,
      colors.inkSoft,
      colors.ink,
    ),
    NotificationKind.verificationApproved => (
      Icons.verified_user_outlined,
      colors.warningSoft,
      colors.warning,
    ),
    NotificationKind.verificationRejected => (
      Icons.gpp_bad_outlined,
      colors.dangerSoft,
      colors.dangerDeep,
    ),
  };
}
