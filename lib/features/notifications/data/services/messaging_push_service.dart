import 'dart:async';

import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/device_tokens_repository.dart';
import 'package:salahly/features/notifications/domain/repositories/push_service.dart';
import 'package:salahly/features/notifications/domain/repositories/push_transport.dart';

/// Registers this phone's push token with the server and hands the
/// messages on. A registration that fails (no internet) is simply tried
/// again at the next [start] or token change.
class MessagingPushService implements PushService {
  MessagingPushService({
    required this._transport,
    required this._devices,
  });

  final PushTransport _transport;
  final DeviceTokensRepository _devices;
  StreamSubscription<String>? _refreshes;

  /// The token last sent to the server, to forget it on [stop].
  String? _registered;

  @override
  bool get isAvailable => _transport.isAvailable;

  @override
  Future<PushPermission> permission() => _transport.permission();

  @override
  Future<PushPermission> requestPermission() async {
    final permission = await _transport.requestPermission();
    if (permission == PushPermission.granted) await start();
    return permission;
  }

  @override
  Future<void> start() async {
    if (!isAvailable) return;
    if (await _transport.permission() != PushPermission.granted) return;
    await _refreshes?.cancel();
    _refreshes = _transport.tokenRefreshes.listen(_register);
    // No token yet (Google services are unreachable): the next start or
    // token refresh registers the phone.
    final token = await _attempt(_transport.token);
    if (token != null) await _register(token);
  }

  @override
  Future<void> stop() async {
    await _refreshes?.cancel();
    _refreshes = null;
    if (!isAvailable) return;
    final token = _registered ?? await _attempt(_transport.token);
    _registered = null;
    // The server first: it needs the session that is about to end.
    if (token != null) await _devices.unregister(token);
    await _attempt(_transport.deleteToken);
  }

  /// Runs [action], giving null when the push channel fails: signing in
  /// or out must never depend on it.
  Future<T?> _attempt<T>(Future<T?> Function() action) async {
    try {
      return await action();
    } on Object {
      return null;
    }
  }

  Future<void> _register(String token) async {
    await _devices.register(token, _transport.platform);
    _registered = token;
  }

  @override
  Stream<PushNotice> get foreground => _transport.foreground;

  @override
  Stream<PushNotice> get opened => _transport.opened;

  @override
  Future<PushNotice?> initialOpened() => _transport.initialOpened();
}
