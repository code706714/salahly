import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/notification_fixtures.dart';

void main() {
  late MockNotificationsRepository repository;
  final now = DateTime(2026, 10, 6, 12);
  final unread = testNotification(NotificationKind.offerReceived, now: now);
  final read = testNotification(
    NotificationKind.jobConfirmed,
    id: 'n2',
    read: true,
    now: now,
  );

  setUpAll(() => registerFallbackValue(UserRole.consumer));

  setUp(() {
    repository = MockNotificationsRepository();
    when(
      () => repository.fetchNotifications(any()),
    ).thenAnswer((_) async => Ok([unread, read]));
    when(
      () => repository.fetchUnreadCount(any()),
    ).thenAnswer((_) async => const Ok(1));
    when(
      () => repository.markRead(any(), ids: any(named: 'ids')),
    ).thenAnswer((_) async => const Ok(null));
  });

  NotificationsCubit build({UserRole role = UserRole.consumer}) =>
      NotificationsCubit(
        notifications: repository,
        role: role,
        now: () => now,
      );

  group('refreshUnread', () {
    blocTest<NotificationsCubit, NotificationsState>(
      "fetches only the count of the cubit's side",
      build: () => build(role: UserRole.technician),
      act: (cubit) => cubit.refreshUnread(),
      expect: () => [const NotificationsState(unread: 1)],
      verify: (_) {
        verify(
          () => repository.fetchUnreadCount(UserRole.technician),
        ).called(1);
        verifyNever(() => repository.fetchNotifications(any()));
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'keeps what is shown when it fails',
      setUp: () => when(
        () => repository.fetchUnreadCount(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      seed: () => const NotificationsState(unread: 4),
      act: (cubit) => cubit.refreshUnread(),
      expect: () => <NotificationsState>[],
    );
  });

  group('load', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'loads the list and the count',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread, read],
          unread: 1,
        ),
      ],
      verify: (_) {
        verify(
          () => repository.fetchNotifications(UserRole.consumer),
        ).called(1);
      },
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'counts the unread ones of the list when the count fails',
      setUp: () => when(
        () => repository.fetchUnreadCount(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread, read],
          unread: 1,
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      "fails when the list can't be loaded",
      setUp: () => when(
        () => repository.fetchNotifications(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotificationsState(
          status: NotificationsStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'shows the loading state again when retrying after a failure',
      build: build,
      seed: () => const NotificationsState(
        status: NotificationsStatus.failed,
        failure: NetworkFailure(),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        const NotificationsState(),
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread, read],
          unread: 1,
        ),
      ],
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'keeps the list when a refresh fails',
      setUp: () => when(
        () => repository.fetchNotifications(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread],
        unread: 1,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread],
          unread: 1,
          failure: const NetworkFailure(),
        ),
      ],
    );
  });

  group('markAllRead', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'shows them read at once and tells the server',
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread, read],
        unread: 1,
      ),
      act: (cubit) => cubit.markAllRead(),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread.markedRead(now), read],
        ),
      ],
      verify: (_) => verify(
        () => repository.markRead(UserRole.consumer, ids: [unread.id]),
      ).called(1),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'marks only the ones shown, not one that arrived since',
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread, read],
        unread: 2,
      ),
      act: (cubit) => cubit.markAllRead(),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread.markedRead(now), read],
          unread: 1,
        ),
      ],
      verify: (_) => verify(
        () => repository.markRead(UserRole.consumer, ids: [unread.id]),
      ).called(1),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'does nothing when everything is read',
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [read],
      ),
      act: (cubit) => cubit.markAllRead(),
      expect: () => <NotificationsState>[],
      verify: (_) => verifyNever(
        () => repository.markRead(any(), ids: any(named: 'ids')),
      ),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      "shows what the server has when it didn't take",
      setUp: () => when(
        () => repository.markRead(any(), ids: any(named: 'ids')),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread, read],
        unread: 1,
      ),
      act: (cubit) => cubit.markAllRead(),
      skip: 1,
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread, read],
          unread: 1,
        ),
      ],
    );
  });

  group('markRead', () {
    blocTest<NotificationsCubit, NotificationsState>(
      'marks one as read and lowers the count',
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread, read],
        unread: 1,
      ),
      act: (cubit) => cubit.markRead('n1'),
      expect: () => [
        NotificationsState(
          status: NotificationsStatus.ready,
          notifications: [unread.markedRead(now), read],
        ),
      ],
      verify: (_) => verify(
        () => repository.markRead(UserRole.consumer, ids: ['n1']),
      ).called(1),
    );

    blocTest<NotificationsCubit, NotificationsState>(
      'ignores one that is read or unknown',
      build: build,
      seed: () => NotificationsState(
        status: NotificationsStatus.ready,
        notifications: [unread, read],
        unread: 1,
      ),
      act: (cubit) async {
        await cubit.markRead('n2');
        await cubit.markRead('nope');
      },
      expect: () => <NotificationsState>[],
      verify: (_) => verifyNever(
        () => repository.markRead(any(), ids: any(named: 'ids')),
      ),
    );
  });
}
