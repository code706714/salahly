part of 'notifications_cubit.dart';

enum NotificationsStatus { loading, ready, failed }

final class NotificationsState extends Equatable {
  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.notifications = const [],
    this.unread = 0,
    this.failure,
  });

  final NotificationsStatus status;

  /// The latest notifications, newest first.
  final List<AppNotification> notifications;

  /// How many are unread, which the bell shows. Known before the list
  /// loads.
  final int unread;

  /// Why the last load failed; the list keeps what was shown before.
  final Failure? failure;

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? notifications,
    int? unread,
    Failure? failure,
  }) => NotificationsState(
    status: status ?? this.status,
    notifications: notifications ?? this.notifications,
    unread: unread ?? this.unread,
    failure: failure ?? this.failure,
  );

  @override
  List<Object?> get props => [status, notifications, unread, failure];
}
