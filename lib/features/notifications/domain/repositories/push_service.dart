import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

/// Push notifications for the signed-in person: this phone is registered
/// with the server after sign-in and forgotten on sign-out, and the
/// messages that arrive or get tapped are handed to the app.
abstract interface class PushService {
  /// Whether this build can receive pushes at all (Firebase is set up).
  bool get isAvailable;

  Future<PushPermission> permission();

  /// Asks the system for permission, then starts if it was given.
  Future<PushPermission> requestPermission();

  /// Registers this phone and keeps it registered as its token changes.
  /// Does nothing without permission; safe to call again.
  Future<void> start();

  /// Forgets this phone: on the server while the session still works, and
  /// its token on the phone. Never throws.
  Future<void> stop();

  /// Messages that arrive while the app is open.
  Stream<PushNotice> get foreground;

  /// Messages the person tapped while the app was running.
  Stream<PushNotice> get opened;

  /// The message whose tap started the app, once; null otherwise.
  Future<PushNotice?> initialOpened();
}
