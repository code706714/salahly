import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';

/// A push message as the app receives it: what happened, for which side of
/// the app, the request it is about, and the text the phone shows. Only
/// what the server sends: no phone number, no address.
final class PushNotice extends Equatable {
  const PushNotice({
    required this.kind,
    required this.role,
    this.requestId,
    this.title,
    this.body,
  });

  final NotificationKind kind;
  final UserRole role;

  /// The request it is about, when it is about one.
  final String? requestId;
  final String? title;
  final String? body;

  @override
  List<Object?> get props => [kind, role, requestId, title, body];
}

/// Whether the person let the app show notifications.
enum PushPermission {
  /// The system has not asked yet (Android 13 and later, iOS).
  notAsked,
  granted,
  denied,
}

/// The kind of phone a push token belongs to.
enum DevicePlatform { android, ios }
