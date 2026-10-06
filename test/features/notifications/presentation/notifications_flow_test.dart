import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/request_page.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/pages/notifications_page.dart';
import 'package:salahly/features/notifications/presentation/widgets/notifications_bell.dart';

import '../../../helpers/consumer_app.dart';
import '../../../helpers/mocks.dart';
import '../../../helpers/notification_fixtures.dart';
import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

/// Makes the server answer with [list].
void _serve(
  MockNotificationsRepository notifications,
  List<AppNotification> list,
) {
  when(
    () => notifications.fetchUnreadCount(any()),
  ).thenAnswer((_) async => Ok(list.where((n) => !n.isRead).length));
  when(
    () => notifications.fetchNotifications(any()),
  ).thenAnswer((_) async => Ok(list));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  testConsumerApp('a consumer sees the unread dot, opens the list and the '
      'request of a notification', (tester, app) async {
    _serve(app.notifications, [
      testNotification(NotificationKind.offerReceived),
      testNotification(NotificationKind.jobConfirmed, id: 'n2', read: true),
    ]);
    when(
      () => app.requests.fetchRequest(any()),
    ).thenAnswer((_) async => const Ok(null));
    await app.pump(tester);

    expect(find.byTooltip('الإشعارات (1 جديدة)'), findsOneWidget);
    await tester.tap(find.byType(NotificationsBell));
    await app.settle(tester);

    expect(find.byType(NotificationsPage), findsOneWidget);
    expect(find.text('وصلك عرض جديد'), findsOneWidget);
    expect(find.text('أحمد رمضان أكّد معادك'), findsOneWidget);
    verify(
      () => app.notifications.fetchNotifications(UserRole.consumer),
    ).called(1);

    await tester.tap(find.text('وصلك عرض جديد'));
    await app.settle(tester);

    verify(
      () => app.notifications.markRead(UserRole.consumer, ids: ['n1']),
    ).called(1);
    expect(find.byType(RequestPage), findsOneWidget);
  });

  testConsumerApp('marking all read empties the dot', (tester, app) async {
    _serve(app.notifications, [
      testNotification(NotificationKind.priceChange),
    ]);
    await app.pump(tester, location: '/consumer/notifications');

    await tester.tap(find.text('علّم الكل اتقرا'));
    await app.settle(tester);

    verify(
      () => app.notifications.markRead(UserRole.consumer, ids: ['n1']),
    ).called(1);
    expect(find.text('علّم الكل اتقرا'), findsNothing);
  });

  testConsumerApp('the count is fetched again when the app comes back', (
    tester,
    app,
  ) async {
    _serve(app.notifications, []);
    await app.pump(tester);
    clearInteractions(app.notifications);
    _serve(app.notifications, [
      testNotification(NotificationKind.offerReceived),
    ]);

    [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await app.settle(tester);

    expect(find.byTooltip('الإشعارات (1 جديدة)'), findsOneWidget);
  });

  testTechnicianApp('a technician opens a new request from the bell', (
    tester,
    app,
  ) async {
    _serve(app.notifications, [testNotification(NotificationKind.newRequest)]);
    await app.pump(tester);

    await tester.tap(find.byType(NotificationsBell));
    await app.settle(tester);
    expect(find.text('طلب جديد في مدينة نصر'), findsOneWidget);
    verify(
      () => app.notifications.fetchNotifications(UserRole.technician),
    ).called(1);

    await tester.tap(find.text('طلب جديد في مدينة نصر'));
    await app.settle(tester);

    verify(
      () => app.notifications.markRead(UserRole.technician, ids: ['n1']),
    ).called(1);
    expect(find.byType(IncomingRequestPage), findsOneWidget);
  });

  testTechnicianApp('the notification of a request that is gone says so', (
    tester,
    app,
  ) async {
    _serve(app.notifications, [testNotification(NotificationKind.newRequest)]);
    when(
      () => app.requests.fetchRequest(any()),
    ).thenAnswer((_) async => const Ok(null));
    await app.pump(tester, location: '/technician/notifications');

    await tester.tap(find.text('طلب جديد في مدينة نصر'));
    await app.settle(tester);

    expect(find.byType(IncomingRequestPage), findsOneWidget);
    expect(find.text('الطلب ده مش موجود.'), findsOneWidget);
  });

  testTechnicianApp('a transfer notification opens the technician balance', (
    tester,
    app,
  ) async {
    _serve(app.notifications, [
      testNotification(NotificationKind.topupApproved, requestId: null),
    ]);
    await app.pump(tester, location: '/technician/notifications');

    await tester.tap(find.text('التحويل اتأكد'));
    await app.settle(tester);

    expect(app.router(tester).state.uri.path, '/technician/account/balance');
  });
}
