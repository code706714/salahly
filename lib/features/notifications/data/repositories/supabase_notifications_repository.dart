import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/data/models/notification_model.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationsRepository implements NotificationsRepository {
  SupabaseNotificationsRepository(this._client);

  final SupabaseClient _client;

  /// How many notifications the list shows.
  static const listLimit = 50;

  @override
  Future<Result<List<AppNotification>>> fetchNotifications(UserRole role) =>
      _call(() async {
        final json = await _client.rpc<List<dynamic>>(
          'my_notifications',
          params: {'p_role': toWire(role), 'p_limit': listLimit},
        );
        return listFromWire(
          json,
        ).map(NotificationModel.fromJson).nonNulls.toList();
      });

  @override
  Future<Result<int>> fetchUnreadCount(UserRole role) => _call(
    () => _client
        .from('notifications')
        .count()
        .eq('role', toWire(role))
        .isFilter('read_at', null),
  );

  @override
  Future<Result<void>> markRead(UserRole role, {List<String>? ids}) =>
      _call(() async {
        await _client.rpc<int>(
          'mark_notifications_read',
          params: {'p_role': toWire(role), 'p_ids': ids},
        );
      });

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(commonFailureFrom(error));
    }
  }
}
