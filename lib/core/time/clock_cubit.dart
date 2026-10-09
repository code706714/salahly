import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// The current time, moved on every minute once started, so labels such as
/// "من 40 دقيقة" or "بكره" stay right while a screen is open.
class ClockCubit extends Cubit<DateTime> {
  ClockCubit({
    this._clock = DateTime.now,
    this._tick = const Duration(minutes: 1),
  }) : super(_clock());

  final DateTime Function() _clock;
  final Duration _tick;
  Timer? _ticker;

  void start() => _ticker ??= Timer.periodic(_tick, (_) => emit(_clock()));

  @override
  Future<void> close() {
    _ticker?.cancel();
    return super.close();
  }
}
