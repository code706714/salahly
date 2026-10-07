import 'dart:async';

import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/push_service.dart';

/// A [PushService] that records what the app asks of it and lets a test
/// send messages through it. By default push is not available, as in a
/// build without Firebase.
class FakePushService implements PushService {
  FakePushService({
    this.isAvailable = false,
    this.currentPermission = PushPermission.denied,
    this.permissionAfterAsking = PushPermission.granted,
    this.initial,
  });

  @override
  final bool isAvailable;

  PushPermission currentPermission;

  /// What the person answers when the system asks.
  PushPermission permissionAfterAsking;
  PushNotice? initial;

  /// Calls in order: 'start', 'stop', 'requestPermission'.
  final calls = <String>[];

  final _foreground = StreamController<PushNotice>.broadcast();
  final _opened = StreamController<PushNotice>.broadcast();

  void receive(PushNotice notice) => _foreground.add(notice);

  void tap(PushNotice notice) => _opened.add(notice);

  @override
  Future<PushPermission> permission() async => currentPermission;

  @override
  Future<PushPermission> requestPermission() async {
    calls.add('requestPermission');
    return currentPermission = permissionAfterAsking;
  }

  @override
  Future<void> start() async => calls.add('start');

  @override
  Future<void> stop() async => calls.add('stop');

  @override
  Stream<PushNotice> get foreground => _foreground.stream;

  @override
  Stream<PushNotice> get opened => _opened.stream;

  @override
  Future<PushNotice?> initialOpened() async {
    final notice = initial;
    initial = null;
    return notice;
  }
}
