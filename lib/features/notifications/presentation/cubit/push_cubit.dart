import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/push_service.dart';

part 'push_state.dart';

/// Push notifications on one side of the app: registers the phone once the
/// person is in, asks permission after explaining why, and hands over the
/// messages that arrive or get tapped.
class PushCubit extends Cubit<PushState> {
  PushCubit(this._push) : super(const PushState());

  final PushService _push;
  StreamSubscription<PushNotice>? _foreground;
  StreamSubscription<PushNotice>? _opened;

  Future<void> start() async {
    if (!_push.isAvailable) {
      emit(state.copyWith(status: PushStatus.unavailable));
      return;
    }
    _foreground = _push.foreground.listen(
      (notice) => emit(state.copyWith(received: PushEvent(notice))),
    );
    _opened = _push.opened.listen(
      (notice) => emit(state.copyWith(opened: PushEvent(notice))),
    );
    switch (await _push.permission()) {
      case PushPermission.granted:
        await _push.start();
        if (isClosed) return;
        emit(state.copyWith(status: PushStatus.active));
      case PushPermission.notAsked:
        emit(state.copyWith(status: PushStatus.needsPermission));
      case PushPermission.denied:
        emit(state.copyWith(status: PushStatus.denied));
    }
    // The message whose tap opened the app, once the listeners are set.
    final initial = await _push.initialOpened();
    if (isClosed || initial == null) return;
    emit(state.copyWith(opened: PushEvent(initial)));
  }

  /// The person agreed to the explanation: the system asks now.
  Future<void> allow() async {
    final permission = await _push.requestPermission();
    if (isClosed) return;
    emit(
      state.copyWith(
        status: permission == PushPermission.granted
            ? PushStatus.active
            : PushStatus.denied,
      ),
    );
  }

  /// "Not now": nothing is asked until the app opens again.
  void later() => emit(state.copyWith(status: PushStatus.deferred));

  @override
  Future<void> close() async {
    await _foreground?.cancel();
    await _opened?.cancel();
    return super.close();
  }
}
