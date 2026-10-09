import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/presentation/cubit/push_cubit.dart';

import '../../../../helpers/fake_push_service.dart';

void main() {
  const arriving = PushNotice(
    kind: NotificationKind.technicianArriving,
    role: UserRole.consumer,
    requestId: '11111111-2222-4333-8444-555555555555',
    title: 'محمود قرّب يوصلك',
  );

  late FakePushService push;
  late PushCubit cubit;

  PushCubit build({
    bool available = true,
    PushPermission permission = PushPermission.granted,
    PushNotice? initial,
  }) {
    push = FakePushService(
      isAvailable: available,
      currentPermission: permission,
      initial: initial,
    );
    return cubit = PushCubit(push);
  }

  tearDown(() => cubit.close());

  group('start', () {
    test('does nothing where Firebase is not set up', () async {
      await build(available: false).start();

      expect(cubit.state.status, PushStatus.unavailable);
      expect(push.calls, isEmpty);
    });

    test('registers the phone when notifications are allowed', () async {
      await build().start();

      expect(cubit.state.status, PushStatus.active);
      expect(push.calls, ['start']);
    });

    test('asks first, explaining why, when the system has not asked', () async {
      await build(permission: PushPermission.notAsked).start();

      expect(cubit.state.status, PushStatus.needsPermission);
      expect(push.calls, isEmpty);
    });

    test('leaves it alone once the person refused', () async {
      await build(permission: PushPermission.denied).start();

      expect(cubit.state.status, PushStatus.denied);
      expect(push.calls, isEmpty);
    });
  });

  group('permission', () {
    test('allowing asks the system and registers the phone', () async {
      await build(permission: PushPermission.notAsked).start();

      await cubit.allow();

      expect(cubit.state.status, PushStatus.active);
      expect(push.calls, ['requestPermission']);
    });

    test('a refusal in the system dialog is remembered', () async {
      await build(permission: PushPermission.notAsked).start();
      push.permissionAfterAsking = PushPermission.denied;

      await cubit.allow();

      expect(cubit.state.status, PushStatus.denied);
    });

    test('"not now" asks nothing', () async {
      await build(permission: PushPermission.notAsked).start();

      cubit.later();

      expect(cubit.state.status, PushStatus.deferred);
      expect(push.calls, isEmpty);
    });
  });

  group('messages', () {
    test('hands on a message that arrives while the app is open', () async {
      await build().start();

      push.receive(arriving);
      await pumpEventQueue();

      expect(cubit.state.received?.notice, arriving);
      expect(cubit.state.opened, isNull);
    });

    test('shows two equal messages one after the other', () async {
      await build().start();
      final received = <PushEvent?>[];
      cubit.stream.listen((state) => received.add(state.received));

      push
        ..receive(arriving)
        ..receive(arriving);
      await pumpEventQueue();

      expect(received.nonNulls, hasLength(2));
    });

    test('hands on a tap while the app is running', () async {
      await build().start();

      push.tap(arriving);
      await pumpEventQueue();

      expect(cubit.state.opened?.notice, arriving);
    });

    test('hands on the tap that started the app', () async {
      await build(initial: arriving).start();

      expect(cubit.state.opened?.notice, arriving);
    });

    test('hears messages even before permission is given', () async {
      await build(permission: PushPermission.notAsked).start();

      push.tap(arriving);
      await pumpEventQueue();

      expect(cubit.state.opened?.notice, arriving);
    });

    test('hears nothing once closed', () async {
      await build().start();
      await cubit.close();

      push.receive(arriving);
      await pumpEventQueue();

      expect(cubit.state.received, isNull);
    });
  });
}
