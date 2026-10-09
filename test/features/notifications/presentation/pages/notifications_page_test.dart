import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:salahly/features/notifications/presentation/pages/notifications_page.dart';
import 'package:salahly/features/notifications/presentation/widgets/notifications_bell.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/notification_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late ConsumerScreenBlocs blocs;
  late MockNotificationsCubit cubit;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    ConsumerApp.registerFallbacks();
  });

  setUp(() {
    blocs = ConsumerScreenBlocs();
    cubit = blocs.notifications;
  });

  void show(NotificationsState state) =>
      when(() => cubit.state).thenReturn(state);

  Future<void> pumpPage(WidgetTester tester, UserRole role) => tester.pumpApp(
    NotificationsView(role: role),
    blocs: blocs.providers,
    stubRoutes: [
      AppRoutes.request('request-1'),
      AppRoutes.incomingRequest('request-1'),
      AppRoutes.consumerBalance,
      AppRoutes.consumerRequests,
    ],
  );

  NotificationsState ready(
    List<AppNotification> notifications, {
    int? unread,
  }) => NotificationsState(
    status: NotificationsStatus.ready,
    notifications: notifications,
    unread: unread ?? notifications.where((n) => !n.isRead).length,
  );

  group('a consumer', () {
    final today = DateTime.now();
    final notifications = [
      testNotification(NotificationKind.priceChange),
      testNotification(
        NotificationKind.offerReceived,
        id: 'n2',
        at: DateTime(today.year, today.month, today.day - 1, 12),
      ),
      testNotification(
        NotificationKind.topupApproved,
        id: 'n3',
        at: DateTime(today.year, today.month, today.day - 4, 12),
        read: true,
        requestId: null,
      ),
    ];

    testWidgets('sees what happened, under today, yesterday and earlier', (
      tester,
    ) async {
      show(ready(notifications));

      await pumpPage(tester, UserRole.consumer);

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('النهارده'), findsOneWidget);
      expect(find.text('امبارح'), findsWidgets);
      expect(find.text('قبل كده'), findsOneWidget);
      expect(
        find.text('أحمد رمضان عايز موافقتك على سعر جديد'),
        findsOneWidget,
      );
      expect(find.text('مش هيكمّل غير لما توافقي.'), findsOneWidget);
      expect(find.text('وصلك عرض جديد'), findsOneWidget);
      expect(find.text('التحويل اتأكد'), findsOneWidget);
      expect(find.text('اتضافوا 5 طلبات لرصيدك'), findsOneWidget);
      expect(find.text('20 د'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('is addressed as a man when he is one', (tester) async {
      when(() => blocs.session.state).thenReturn(
        testConsumerSession(honorific: Honorific.mr),
      );
      show(ready(notifications));

      await pumpPage(tester, UserRole.consumer);

      expect(find.text('مش هيكمّل غير لما توافق.'), findsOneWidget);
    });

    testWidgets('opens the request of a notification and marks it read', (
      tester,
    ) async {
      show(ready(notifications));
      await pumpPage(tester, UserRole.consumer);

      await tester.tap(find.text('وصلك عرض جديد'));
      await tester.pumpAndSettle();

      verify(() => cubit.markRead('n2')).called(1);
      expect(find.text(AppRoutes.request('request-1')), findsOneWidget);
    });

    testWidgets('opens the balance for a transfer', (tester) async {
      show(ready(notifications));
      await pumpPage(tester, UserRole.consumer);

      await tester.tap(find.text('التحويل اتأكد'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerBalance), findsOneWidget);
    });

    testWidgets('marks everything read from the top bar', (tester) async {
      show(ready(notifications));
      await pumpPage(tester, UserRole.consumer);

      await tester.tap(find.text('علّم الكل اتقرا'));

      verify(cubit.markAllRead).called(1);
    });

    testWidgets('has no "mark all" when all are read', (tester) async {
      show(ready([notifications.last]));

      await pumpPage(tester, UserRole.consumer);

      expect(find.text('علّم الكل اتقرا'), findsNothing);
    });

    testWidgets('shows a friendly empty state', (tester) async {
      show(ready(const []));

      await pumpPage(tester, UserRole.consumer);

      expect(find.text('مفيش إشعارات لسه'), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a spinner while loading', (tester) async {
      show(const NotificationsState());

      await tester.pumpApp(
        const NotificationsView(role: UserRole.consumer),
        blocs: blocs.providers,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('can retry a failed load, in her grammar', (tester) async {
      show(
        const NotificationsState(
          status: NotificationsStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpPage(tester, UserRole.consumer);

      expect(find.text('مفيش نت. اتأكدي من النت وجرّبي تاني.'), findsOneWidget);
      await tester.tap(find.text('جرّبي تاني'));

      verify(cubit.load).called(1);
    });
  });

  group('a technician', () {
    testWidgets('sees a new request with its distance, in plain copy', (
      tester,
    ) async {
      show(ready([testNotification(NotificationKind.newRequest)]));

      await pumpPage(tester, UserRole.technician);

      expect(find.text('طلب جديد في مدينة نصر'), findsOneWidget);
      expect(find.textContaining('2.4 كم منك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the incoming request', (tester) async {
      show(ready([testNotification(NotificationKind.newRequest)]));
      await pumpPage(tester, UserRole.technician);

      await tester.tap(find.text('طلب جديد في مدينة نصر'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.incomingRequest('request-1')), findsOneWidget);
    });

    testWidgets('is told a failure in the common words', (tester) async {
      show(
        const NotificationsState(
          status: NotificationsStatus.failed,
          failure: UnexpectedFailure(),
        ),
      );

      await pumpPage(tester, UserRole.technician);

      expect(find.text('حصلت مشكلة عندنا. جرّب تاني.'), findsOneWidget);
      expect(find.text('جرّب تاني'), findsOneWidget);
    });

    testWidgets('fits the smallest phone with long texts', (tester) async {
      show(
        ready([
          testNotification(NotificationKind.offerPicked, id: 'a'),
          testNotification(NotificationKind.verificationRejected, id: 'b'),
          testNotification(NotificationKind.newRequest, id: 'c'),
        ]),
      );

      await pumpPage(tester, UserRole.technician);

      expect(tester.takeException(), isNull);
    });
  });

  group('the bell', () {
    Future<void> pumpBell(WidgetTester tester, int unread) async {
      show(NotificationsState(unread: unread));
      await tester.pumpApp(
        const Scaffold(body: NotificationsBell(role: UserRole.consumer)),
        blocs: blocs.providers,
        stubRoutes: [AppRoutes.consumerNotifications],
      );
    }

    testWidgets('says how many are unread', (tester) async {
      await pumpBell(tester, 3);

      expect(find.byTooltip('الإشعارات (3 جديدة)'), findsOneWidget);
    });

    testWidgets('has no count when all are read', (tester) async {
      await pumpBell(tester, 0);

      expect(find.byTooltip('الإشعارات'), findsOneWidget);
    });

    testWidgets('opens the notifications', (tester) async {
      await pumpBell(tester, 1);

      await tester.tap(find.byType(NotificationsBell));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerNotifications), findsOneWidget);
    });
  });
}
