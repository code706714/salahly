import 'package:salahly/features/calls/domain/entities/call.dart';

/// How the voice link is doing.
enum CallLink { connecting, connected, failed }

/// The phone's side of a voice call: the microphone, the speaker and the
/// peer-to-peer link.
abstract interface class CallEngine {
  /// Handshake messages for the other side, as the link finds them.
  Stream<CallSignalDraft> get outgoing;

  Stream<CallLink> get link;

  /// Takes the microphone and readies the link; false when the microphone
  /// is not allowed.
  Future<bool> open();

  /// The caller's first step: makes the offer.
  Future<void> offer();

  /// Takes a handshake message from the other side.
  Future<void> receive(CallSignal signal);

  void setMuted({required bool muted});

  Future<void> setSpeaker({required bool on});

  Future<void> close();
}

typedef CallEngineFactory = CallEngine Function();
