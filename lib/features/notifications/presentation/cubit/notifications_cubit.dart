import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/repositories/notifications_repository.dart';

part 'notifications_state.dart';

/// One side's notifications: how many are unread (for the bell), the list
/// and marking them read.
class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit({
    required this._notifications,
    required this._role,
    this._now = DateTime.now,
  }) : super(const NotificationsState());

  final NotificationsRepository _notifications;
  final UserRole _role;
  final DateTime Function() _now;
  late final _loadList = SingleFlight(_fetchList);
  late final _loadCount = SingleFlight(_fetchCount);

  /// Fetches only how many are unread, for the bell. A failure keeps what
  /// is shown.
  Future<void> refreshUnread() => _loadCount();

  /// Fetches the list and the count again. A failed refresh keeps what is
  /// shown.
  Future<void> load() => _loadList();

  /// Marks every unread notification as read.
  Future<void> markAllRead() async {
    if (state.unread == 0 && state.notifications.every((n) => n.isRead)) {
      return;
    }
    final at = _now();
    emit(
      state.copyWith(
        notifications: [for (final n in state.notifications) n.markedRead(at)],
        unread: 0,
      ),
    );
    await _mark(null);
  }

  /// Marks the notification [id] as read, as when it is opened.
  Future<void> markRead(String id) async {
    final target = state.notifications.where((n) => n.id == id).firstOrNull;
    if (target == null || target.isRead) return;
    final at = _now();
    emit(
      state.copyWith(
        notifications: [
          for (final n in state.notifications)
            n.id == id ? n.markedRead(at) : n,
        ],
        unread: state.unread > 0 ? state.unread - 1 : 0,
      ),
    );
    await _mark([id]);
  }

  /// Tells the server; if it didn't take, shows what the server has.
  Future<void> _mark(List<String>? ids) async {
    final result = await _notifications.markRead(_role, ids: ids);
    if (isClosed) return;
    if (result is Err) await load();
  }

  Future<void> _fetchCount() async {
    final result = await _notifications.fetchUnreadCount(_role);
    if (isClosed) return;
    if (result case Ok(value: final unread)) {
      emit(state.copyWith(unread: unread));
    }
  }

  Future<void> _fetchList() async {
    if (state.status == NotificationsStatus.failed) {
      emit(const NotificationsState());
    }
    final (list, count) = await (
      _notifications.fetchNotifications(_role),
      _notifications.fetchUnreadCount(_role),
    ).wait;
    if (isClosed) return;
    switch (list) {
      case Ok(value: final notifications):
        emit(
          NotificationsState(
            status: NotificationsStatus.ready,
            notifications: notifications,
            unread: switch (count) {
              Ok(value: final unread) => unread,
              Err() => notifications.where((n) => !n.isRead).length,
            },
          ),
        );
      case Err(:final failure):
        emit(
          NotificationsState(
            status: state.status == NotificationsStatus.ready
                ? NotificationsStatus.ready
                : NotificationsStatus.failed,
            notifications: state.notifications,
            unread: state.unread,
            failure: failure,
          ),
        );
    }
  }
}
