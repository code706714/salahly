import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

/// Reads the data a push message carries. It comes from outside the app, so
/// nothing is trusted: an unknown kind or side drops the message, and a
/// request id that is not a uuid is ignored.
abstract final class PushNoticeModel {
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );

  static PushNotice? fromMessage({
    required Map<String, dynamic> data,
    String? title,
    String? body,
  }) {
    final kind = NotificationKind.values
        .where((kind) => toWire(kind) == data['kind'])
        .firstOrNull;
    final role = UserRole.values
        .where((role) => role.name == data['role'])
        .firstOrNull;
    if (kind == null || role == null) return null;
    final requestId = data['request_id'];
    return PushNotice(
      kind: kind,
      role: role,
      requestId: requestId is String && _uuid.hasMatch(requestId)
          ? requestId
          : null,
      title: title,
      body: body,
    );
  }
}
