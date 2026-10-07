import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:salahly/features/notifications/data/models/push_notice_model.dart';
import 'package:salahly/features/notifications/data/services/no_push_transport.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/push_transport.dart';

/// Firebase Cloud Messaging on an Android phone whose Firebase app was
/// initialised.
class FirebasePushTransport implements PushTransport {
  FirebasePushTransport(this._messaging);

  final FirebaseMessaging _messaging;

  @override
  bool get isAvailable => true;

  @override
  DevicePlatform get platform => DevicePlatform.android;

  @override
  Future<PushPermission> permission() async =>
      _permissionOf(await _messaging.getNotificationSettings());

  @override
  Future<PushPermission> requestPermission() async =>
      _permissionOf(await _messaging.requestPermission());

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Future<void> deleteToken() => _messaging.deleteToken();

  @override
  Stream<PushNotice> get foreground => _notices(FirebaseMessaging.onMessage);

  @override
  Stream<PushNotice> get opened =>
      _notices(FirebaseMessaging.onMessageOpenedApp);

  @override
  Future<PushNotice?> initialOpened() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _noticeOf(message);
  }

  /// The messages this app understands; any other is dropped.
  static Stream<PushNotice> _notices(Stream<RemoteMessage> messages) async* {
    await for (final message in messages) {
      if (_noticeOf(message) case final notice?) yield notice;
    }
  }

  static PushPermission _permissionOf(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notAsked,
      };

  static PushNotice? _noticeOf(RemoteMessage message) {
    final notification = message.notification;
    return PushNoticeModel.fromMessage(
      data: message.data,
      title: notification?.title,
      body: notification?.body,
    );
  }
}

/// The push channel for this build: Firebase on Android when its
/// configuration (`google-services.json`) was built in, else
/// [NoPushTransport]. Initialising Firebase without a configuration throws;
/// that is how the missing file shows, and the app carries on without push.
Future<PushTransport> createPushTransport() async {
  if (defaultTargetPlatform != TargetPlatform.android || kIsWeb) {
    return const NoPushTransport();
  }
  try {
    await Firebase.initializeApp();
    return FirebasePushTransport(FirebaseMessaging.instance);
  } on Object {
    return const NoPushTransport();
  }
}
