import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/push_transport.dart';

/// The push channel of a build where Firebase isn't set up (no
/// `google-services.json`, or not Android): nothing is registered and
/// nothing arrives.
class NoPushTransport implements PushTransport {
  const NoPushTransport();

  @override
  bool get isAvailable => false;

  @override
  DevicePlatform get platform => DevicePlatform.android;

  @override
  Future<PushPermission> permission() async => PushPermission.denied;

  @override
  Future<PushPermission> requestPermission() async => PushPermission.denied;

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Stream<PushNotice> get foreground => const Stream.empty();

  @override
  Stream<PushNotice> get opened => const Stream.empty();

  @override
  Future<PushNotice?> initialOpened() async => null;
}
