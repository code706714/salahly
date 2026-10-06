import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';

/// The person's notifications on one side of the app. The server writes
/// them as things happen; here they are read and marked read.
abstract interface class NotificationsRepository {
  /// The latest notifications of [role], newest first.
  Future<Result<List<AppNotification>>> fetchNotifications(UserRole role);

  /// How many of [role]'s notifications are still unread.
  Future<Result<int>> fetchUnreadCount(UserRole role);

  /// Marks [ids], or every unread one of [role] when [ids] is null, as read.
  /// The app always passes the ids it shows, so a notification that arrived
  /// since the list was fetched stays unread.
  Future<Result<void>> markRead(UserRole role, {List<String>? ids});
}
