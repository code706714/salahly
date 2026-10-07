import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/push_service.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:salahly/features/notifications/presentation/widgets/push_scope.dart';

import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/fake_push_service.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/notification_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  const requestId = '11111111-2222-4333-8444-555555555555';
  const arriving = PushNotice(
    kind: NotificationKind.technicianArriving,
    role: UserRole.consumer,
    requestId: requestId,
    title: 'محمود قرّب يوصلك',
    body: 'خلّي تليفونك معاك.',
  );

  late MockSessionCubit session;
  late MockNotificationsCubit notifications;

  setUpAll(loadAppFonts);

  setUp(() {
    session = MockSessionCubit();
    when(() => session.state).thenReturn(testConsumerSession());
    notifications = mockNotificationsCubit();
  });

  Future<void> pump(
    WidgetTester tester,
    FakePushService push, {
    UserRole role = UserRole.consumer,
  }) async {
    await tester.pumpApp(
      PushScope(
        role: role,
        child: const Scaffold(body: Text('الصفحة')),
      ),
      repositories: [RepositoryProvider<PushService>.value(value: push)],
      blocs: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<NotificationsCubit>.value(value: notifications),
      ],
      stubRoutes: [
        AppRoutes.request(requestId),
        AppRoutes.incomingRequest(requestId),
      ],
    );
    await tester.pump();
  }

  FakePushService available({
    PushPermission permission = PushPermission.granted,
    PushNotice? initial,
  }) => FakePushService(
    isAvailable: true,
    currentPermission: permission,
    initial: initial,
  );

  group('permission', () {
    testWidgets('explains before the system asks, in her grammar', (
      tester,
    ) async {
      final push = available(permission: PushPermission.notAsked);
      await pump(tester, push);
      await tester.pumpAndSettle();

      expect(find.text(l10n.pushRationaleTitle), findsOneWidget);
      expect(find.text(l10n.pushRationaleConsumer('ms')), findsOneWidget);
      expect(push.calls, isEmpty);

      await tester.tap(find.text(l10n.pushRationaleAllow));
      await tester.pumpAndSettle();

      expect(push.calls, ['requestPermission']);
      expect(find.text(l10n.pushRationaleTitle), findsNothing);
    });

    testWidgets('explains in his grammar to a man', (tester) async {
      when(
        () => session.state,
      ).thenReturn(testConsumerSession(honorific: Honorific.mr));
      await pump(tester, available(permission: PushPermission.notAsked));
      await tester.pumpAndSettle();

      expect(find.text(l10n.pushRationaleConsumer('mr')), findsOneWidget);
    });

    testWidgets('tells a technician what he will hear about', (tester) async {
      await pump(
        tester,
        available(permission: PushPermission.notAsked),
        role: UserRole.technician,
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.pushRationaleTechnician), findsOneWidget);
    });

    testWidgets('"not now" asks the system nothing', (tester) async {
      final push = available(permission: PushPermission.notAsked);
      await pump(tester, push);
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.pushRationaleLater));
      await tester.pumpAndSettle();

      expect(push.calls, isEmpty);
      expect(find.text(l10n.pushRationaleTitle), findsNothing);
    });

    testWidgets('does not ask again once allowed, nor where unavailable', (
      tester,
    ) async {
      await pump(tester, available());
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushRationaleTitle), findsNothing);

      await pump(tester, FakePushService());
      await tester.pumpAndSettle();
      expect(find.text(l10n.pushRationaleTitle), findsNothing);
    });
  });

  group('a message while the app is open', () {
    testWidgets('shows it and refreshes the notification list', (tester) async {
      final push = available();
      await pump(tester, push);

      push.receive(arriving);
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('محمود قرّب يوصلك'), findsOneWidget);
      expect(find.text(l10n.pushOpen), findsOneWidget);
      verify(notifications.load).called(1);
    });

    testWidgets('opens the request from the message', (tester) async {
      final push = available();
      await pump(tester, push);

      push.receive(arriving);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.pushOpen));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.request(requestId)), findsOneWidget);
    });

    testWidgets('offers no way to open a message for the other side', (
      tester,
    ) async {
      final push = available();
      await pump(tester, push);

      push.receive(
        const PushNotice(
          kind: NotificationKind.newRequest,
          role: UserRole.technician,
          requestId: requestId,
          title: 'طلب جديد',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('طلب جديد'), findsOneWidget);
      expect(find.text(l10n.pushOpen), findsNothing);
    });

    testWidgets('only refreshes when the message has no text', (tester) async {
      final push = available();
      await pump(tester, push);

      push.receive(
        const PushNotice(
          kind: NotificationKind.jobStarted,
          role: UserRole.consumer,
        ),
      );
      await tester.pump();

      verify(notifications.load).called(1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('a tap on a message', () {
    testWidgets("opens the consumer's request", (tester) async {
      final push = available();
      await pump(tester, push);

      push.tap(arriving);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.request(requestId)), findsOneWidget);
    });

    testWidgets("opens the technician's incoming request", (tester) async {
      final push = available();
      await pump(tester, push, role: UserRole.technician);

      push.tap(
        const PushNotice(
          kind: NotificationKind.offerPicked,
          role: UserRole.technician,
          requestId: requestId,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.incomingRequest(requestId)), findsOneWidget);
    });

    testWidgets('opens the request that started the app', (tester) async {
      await pump(tester, available(initial: arriving));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.request(requestId)), findsOneWidget);
    });

    testWidgets('goes nowhere for a message meant for the other side', (
      tester,
    ) async {
      final push = available();
      await pump(tester, push);

      push.tap(
        const PushNotice(
          kind: NotificationKind.newRequest,
          role: UserRole.technician,
          requestId: requestId,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الصفحة'), findsOneWidget);
      expect(find.text(AppRoutes.incomingRequest(requestId)), findsNothing);
    });

    testWidgets('lands on the list when it names no request', (tester) async {
      final push = available();
      await tester.pumpApp(
        const PushScope(
          role: UserRole.consumer,
          child: Scaffold(body: Text('الصفحة')),
        ),
        repositories: [RepositoryProvider<PushService>.value(value: push)],
        blocs: [
          BlocProvider<SessionCubit>.value(value: session),
          BlocProvider<NotificationsCubit>.value(value: notifications),
        ],
        stubRoutes: [AppRoutes.consumerRequests],
      );
      await tester.pump();

      push.tap(
        const PushNotice(
          kind: NotificationKind.requestExpired,
          role: UserRole.consumer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerRequests), findsOneWidget);
    });
  });
}
