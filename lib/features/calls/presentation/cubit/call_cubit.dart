import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/failures/call_failures.dart';
import 'package:salahly/features/calls/domain/repositories/call_repository.dart';
import 'package:salahly/features/calls/domain/services/call_engine.dart';
import 'package:salahly/features/calls/domain/services/call_ringer.dart';

part 'call_state.dart';

/// One voice call, made or taken.
///
/// A call made is [start]ed; a call taken is given its id, rings until
/// [accept] or [decline], and rings no longer than [_ringFor] either way.
/// An answered call whose voice link is not up within [_connectFor] failed.
class CallCubit extends Cubit<CallState> {
  CallCubit({
    required this._calls,
    required this._engine,
    required this._ringer,
    required this._requestId,
    required this._technicianId,
    String? incomingCallId,
    this._ringFor = const Duration(seconds: 45),
    this._connectFor = const Duration(seconds: 25),
  }) : _callId = incomingCallId,
       super(
         CallState(
           phase: incomingCallId == null
               ? CallPhase.starting
               : CallPhase.incoming,
         ),
       );

  final CallRepository _calls;
  final CallEngine _engine;
  final CallRinger _ringer;
  final String _requestId;
  final String _technicianId;
  final Duration _ringFor;
  final Duration _connectFor;
  Timer? _connectTimer;
  String? _callId;
  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _ringTimer;
  Timer? _ticker;
  Future<void> _queue = Future.value();

  /// Rings the other side, or waits for the answer to a ringing call.
  Future<void> start() async {
    if (state.phase == CallPhase.incoming) {
      unawaited(_ringer.start(incoming: true));
      _watchStatus();
      _ringTimer = Timer(_ringFor, () => _finish(CallEnd.missed));
      return;
    }
    if (!await _engine.open()) return _finish(CallEnd.microphone);
    final result = await _calls.start(_requestId, _technicianId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _callId = value;
      case Err(:final failure):
        return _finish(switch (failure) {
          CalleeBusyFailure() => CallEnd.busy,
          CallInProgressFailure() => CallEnd.alreadyCalling,
          CallUnavailableFailure() => CallEnd.unavailable,
          _ => CallEnd.failed,
        }, tellServer: false);
    }
    _listen();
    _ringTimer = Timer(_ringFor, () => _finish(CallEnd.missed));
    emit(state.copyWith(phase: CallPhase.ringing));
    await _guarded(_engine.offer);
  }

  /// Takes the ringing call.
  Future<void> accept() async {
    final id = _callId;
    if (id == null || state.phase != CallPhase.incoming) return;
    emit(state.copyWith(phase: CallPhase.connecting));
    _ringTimer?.cancel();
    if (!await _engine.open()) return _finish(CallEnd.microphone);
    final result = await _calls.answer(id);
    if (isClosed || state.phase == CallPhase.ended) return;
    if (result is Err) {
      return _finish(CallEnd.unavailable, tellServer: false);
    }
    _listen();
  }

  /// Turns the ringing call down, or cancels the one being made.
  Future<void> decline() async => _finish(
    state.phase == CallPhase.incoming ? CallEnd.declined : CallEnd.hungUp,
  );

  Future<void> hangUp() async => _finish(CallEnd.hungUp);

  void toggleMute() {
    final muted = !state.muted;
    _engine.setMuted(muted: muted);
    emit(state.copyWith(muted: muted));
  }

  Future<void> toggleSpeaker() async {
    final on = !state.speaker;
    await _engine.setSpeaker(on: on);
    if (!isClosed) emit(state.copyWith(speaker: on));
  }

  void _watchStatus() {
    final id = _callId!;
    _subscriptions.add(
      _calls.statuses(id).listen((status) {
        switch (status) {
          case CallStatus.ringing:
            break;
          case CallStatus.answered:
            if (state.phase == CallPhase.ringing) {
              _ringTimer?.cancel();
              emit(state.copyWith(phase: CallPhase.connecting));
            }
          case CallStatus.declined:
            _finish(CallEnd.declined, tellServer: false);
          case CallStatus.missed:
            _finish(CallEnd.missed, tellServer: false);
          case CallStatus.ended:
            _finish(CallEnd.remoteEnded, tellServer: false);
        }
      }),
    );
  }

  /// Starts the handshake: what the other side sends goes to the engine and
  /// what the engine finds goes to the other side, each in order.
  void _listen() {
    final id = _callId!;
    if (_subscriptions.isEmpty) _watchStatus();
    _subscriptions
      ..add(
        _calls
            .signals(id)
            .listen(
              (signal) => _enqueue(() => _engine.receive(signal)),
            ),
      )
      ..add(
        _engine.outgoing.listen(
          (draft) => _enqueue(() async {
            final result = await _calls.sendSignal(id, draft);
            if (result is Err) _finish(CallEnd.failed);
          }),
        ),
      )
      ..add(
        _engine.link.listen((link) {
          switch (link) {
            case CallLink.connecting:
              break;
            case CallLink.connected:
              _ticker ??= Timer.periodic(
                const Duration(seconds: 1),
                (_) => emit(state.copyWith(seconds: state.seconds + 1)),
              );
              emit(state.copyWith(phase: CallPhase.connected));
            case CallLink.failed:
              _finish(CallEnd.failed);
          }
        }),
      );
  }

  /// The ring sounds while the call rings, on either side, and stops the
  /// moment it is answered, turned down or over.
  @override
  void onChange(Change<CallState> change) {
    super.onChange(change);
    final before = change.currentState.phase;
    final after = change.nextState.phase;
    if (before == after) return;
    switch (after) {
      case CallPhase.incoming:
        unawaited(_ringer.start(incoming: true));
      case CallPhase.ringing:
        unawaited(_ringer.start(incoming: false));
      case CallPhase.connecting:
        unawaited(_ringer.stop());
        _connectTimer ??= Timer(_connectFor, () => _finish(CallEnd.failed));
      case CallPhase.starting || CallPhase.connected || CallPhase.ended:
        unawaited(_ringer.stop());
        _connectTimer?.cancel();
    }
  }

  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => _guarded(job));
  }

  Future<void> _guarded(Future<void> Function() job) async {
    try {
      await job();
    } on Object {
      _finish(CallEnd.failed);
    }
  }

  void _finish(CallEnd reason, {bool tellServer = true}) {
    if (isClosed || state.phase == CallPhase.ended) return;
    final id = _callId;
    if (tellServer && id != null) unawaited(_calls.end(id));
    _release();
    emit(state.copyWith(phase: CallPhase.ended, end: reason));
  }

  void _release() {
    _ringTimer?.cancel();
    _connectTimer?.cancel();
    _ticker?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    unawaited(_engine.close());
  }

  @override
  Future<void> close() {
    if (state.phase != CallPhase.ended) {
      final id = _callId;
      if (id != null) unawaited(_calls.end(id));
      _release();
    }
    unawaited(_ringer.stop());
    return super.close();
  }
}
