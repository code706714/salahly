import 'dart:async';

import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/services/call_engine.dart';

/// A [CallEngine] a test drives by hand.
class FakeCallEngine implements CallEngine {
  final outgoingController = StreamController<CallSignalDraft>.broadcast();
  final linkController = StreamController<CallLink>.broadcast();
  final received = <CallSignal>[];

  /// What [open] answers; false is a microphone that is not allowed.
  bool microphoneAllowed = true;
  bool opened = false;
  bool offered = false;
  bool closed = false;
  bool? muted;
  bool? speaker;

  @override
  Stream<CallSignalDraft> get outgoing => outgoingController.stream;

  @override
  Stream<CallLink> get link => linkController.stream;

  @override
  Future<bool> open() async => opened = microphoneAllowed;

  @override
  Future<void> offer() async => offered = true;

  @override
  Future<void> receive(CallSignal signal) async => received.add(signal);

  @override
  void setMuted({required bool muted}) => this.muted = muted;

  @override
  Future<void> setSpeaker({required bool on}) async => speaker = on;

  @override
  Future<void> close() async => closed = true;
}
