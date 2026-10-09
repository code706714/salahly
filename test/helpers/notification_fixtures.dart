import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';

import 'mocks.dart';

class MockNotificationsCubit extends MockCubit<NotificationsState>
    implements NotificationsCubit {}

/// A mock cubit showing [state] and answering its fetches.
MockNotificationsCubit mockNotificationsCubit([
  NotificationsState state = const NotificationsState(
    status: NotificationsStatus.ready,
  ),
]) {
  final cubit = MockNotificationsCubit();
  when(() => cubit.state).thenReturn(state);
  when(cubit.load).thenAnswer((_) async {});
  when(cubit.refreshUnread).thenAnswer((_) async {});
  when(cubit.markAllRead).thenAnswer((_) async {});
  when(() => cubit.markRead(any())).thenAnswer((_) async {});
  return cubit;
}

/// Makes [notifications] answer "none, nothing unread" to everything, so
/// screens that show the bell work without a test caring about it.
void stubNotifications(MockNotificationsRepository notifications) {
  when(
    () => notifications.fetchUnreadCount(any()),
  ).thenAnswer((_) async => const Ok(0));
  when(
    () => notifications.fetchNotifications(any()),
  ).thenAnswer((_) async => const Ok([]));
  when(
    () => notifications.markRead(any(), ids: any(named: 'ids')),
  ).thenAnswer((_) async => const Ok(null));
}

/// A notification of [kind] with the data its text needs, made at [at], or
/// [ago] before [now] (or before the real now), unread unless [read].
AppNotification testNotification(
  NotificationKind kind, {
  String id = 'n1',
  Duration ago = const Duration(minutes: 20),
  DateTime? now,
  DateTime? at,
  bool read = false,
  String? requestId = 'request-1',
}) {
  final created = at ?? (now ?? DateTime.now()).subtract(ago);
  return AppNotification(
    id: id,
    kind: kind,
    createdAt: created,
    readAt: read ? created : null,
    requestId: requestId,
    topupId: kind.isAboutTopup ? 'topup-1' : null,
    categoryId: 'ac',
    issue: RequestIssue.notCooling,
    areaId: 'nasr_city',
    day: DateTime(2026, 10, 8),
    window: RequestWindow.noon,
    pricePiastres: 35000,
    arriveAt: DateTime(2026, 10, 8, 13),
    technicianName: 'أحمد رمضان',
    consumerName: 'نورهان م.',
    consumerHonorific: Honorific.ms,
    distanceKm: 2.4,
    topupUses: 5,
  );
}
