import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

/// The phone's push channel (Firebase Cloud Messaging): the permission, this
/// phone's token and the messages that arrive. Where push isn't set up
/// ([isAvailable] false) nothing here does anything.
abstract interface class PushTransport {
  bool get isAvailable;

  DevicePlatform get platform;

  Future<PushPermission> permission();

  /// Asks the system for permission; returns what the person answered.
  Future<PushPermission> requestPermission();

  /// This phone's token, or null when there is none yet.
  Future<String?> token();

  /// Every new token the phone gets later.
  Stream<String> get tokenRefreshes;

  /// Forgets this phone's token, so that a new one is made for the next
  /// person to sign in.
  Future<void> deleteToken();

  /// Messages that arrive while the app is open.
  Stream<PushNotice> get foreground;

  /// Messages the person tapped while the app was running.
  Stream<PushNotice> get opened;

  /// The message whose tap started the app, once; null otherwise.
  Future<PushNotice?> initialOpened();
}
