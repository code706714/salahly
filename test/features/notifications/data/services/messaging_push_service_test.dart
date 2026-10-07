import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/data/services/messaging_push_service.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockPushTransport transport;
  late MockDeviceTokensRepository devices;
  late StreamController<String> refreshes;
  late MessagingPushService service;

  setUpAll(() => registerFallbackValue(DevicePlatform.android));

  setUp(() {
    transport = MockPushTransport();
    devices = MockDeviceTokensRepository();
    refreshes = StreamController<String>.broadcast();
    when(() => transport.isAvailable).thenReturn(true);
    when(() => transport.platform).thenReturn(DevicePlatform.android);
    when(
      () => transport.permission(),
    ).thenAnswer((_) async => PushPermission.granted);
    when(() => transport.token()).thenAnswer((_) async => 'token-1');
    when(() => transport.tokenRefreshes).thenAnswer((_) => refreshes.stream);
    when(() => transport.deleteToken()).thenAnswer((_) async {});
    when(
      () => devices.register(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => devices.unregister(any()),
    ).thenAnswer((_) async => const Ok(null));
    service = MessagingPushService(transport: transport, devices: devices);
  });

  tearDown(() => refreshes.close());

  group('start', () {
    test('registers this phone', () async {
      await service.start();

      verify(
        () => devices.register('token-1', DevicePlatform.android),
      ).called(1);
    });

    test('registers every new token the phone gets', () async {
      await service.start();
      refreshes.add('token-2');
      await pumpEventQueue();

      verify(
        () => devices.register('token-2', DevicePlatform.android),
      ).called(1);
    });

    test('registers nothing without permission', () async {
      when(
        () => transport.permission(),
      ).thenAnswer((_) async => PushPermission.notAsked);

      await service.start();
      refreshes.add('token-2');
      await pumpEventQueue();

      verifyNever(() => devices.register(any(), any()));
    });

    test('does nothing where push is not set up', () async {
      when(() => transport.isAvailable).thenReturn(false);

      await service.start();

      verifyNever(() => transport.token());
      verifyNever(() => devices.register(any(), any()));
    });

    test('carries on when the phone has no token yet', () async {
      when(() => transport.token()).thenThrow(StateError('no google'));

      await service.start();
      refreshes.add('token-2');
      await pumpEventQueue();

      verify(
        () => devices.register('token-2', DevicePlatform.android),
      ).called(1);
    });

    test('is tried again later when the server cannot be reached', () async {
      when(
        () => devices.register(any(), any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));

      await service.start();
      await service.start();

      verify(
        () => devices.register('token-1', DevicePlatform.android),
      ).called(2);
    });
  });

  group('stop', () {
    test('forgets the phone on the server, then on the phone', () async {
      await service.start();
      final order = <String>[];
      when(() => devices.unregister(any())).thenAnswer((_) async {
        order.add('server');
        return const Ok(null);
      });
      when(() => transport.deleteToken()).thenAnswer((_) async {
        order.add('phone');
      });

      await service.stop();

      expect(order, ['server', 'phone']);
      verify(() => devices.unregister('token-1')).called(1);
    });

    test('stops following token changes', () async {
      await service.start();
      await service.stop();
      clearInteractions(devices);

      refreshes.add('token-2');
      await pumpEventQueue();

      verifyNever(() => devices.register(any(), any()));
    });

    test('finds the token even if it never registered', () async {
      await service.stop();

      verify(() => devices.unregister('token-1')).called(1);
    });

    test('never throws, even offline or without Google services', () async {
      when(() => transport.token()).thenThrow(StateError('no google'));
      when(() => transport.deleteToken()).thenThrow(StateError('offline'));

      await service.stop();

      verifyNever(() => devices.unregister(any()));
    });

    test('does nothing where push is not set up', () async {
      when(() => transport.isAvailable).thenReturn(false);

      await service.stop();

      verifyNever(() => devices.unregister(any()));
      verifyNever(() => transport.deleteToken());
    });
  });

  group('permission', () {
    test('asks the system and registers once it is given', () async {
      when(
        () => transport.requestPermission(),
      ).thenAnswer((_) async => PushPermission.granted);

      expect(await service.requestPermission(), PushPermission.granted);

      verify(
        () => devices.register('token-1', DevicePlatform.android),
      ).called(1);
    });

    test('registers nothing when the person refuses', () async {
      when(
        () => transport.requestPermission(),
      ).thenAnswer((_) async => PushPermission.denied);

      expect(await service.requestPermission(), PushPermission.denied);

      verifyNever(() => devices.register(any(), any()));
    });
  });

  test('hands on the messages that arrive and get tapped', () async {
    const notice = PushNotice(
      kind: NotificationKind.jobStarted,
      role: UserRole.consumer,
    );
    when(() => transport.foreground).thenAnswer((_) => Stream.value(notice));
    when(() => transport.opened).thenAnswer((_) => Stream.value(notice));
    when(() => transport.initialOpened()).thenAnswer((_) async => notice);

    expect(await service.foreground.first, notice);
    expect(await service.opened.first, notice);
    expect(await service.initialOpened(), notice);
  });
}
