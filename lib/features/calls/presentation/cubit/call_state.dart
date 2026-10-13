part of 'call_cubit.dart';

/// Where the call is, from the screen's side.
enum CallPhase { starting, ringing, incoming, connecting, connected, ended }

/// Why a call is over.
enum CallEnd {
  hungUp,
  remoteEnded,
  declined,
  missed,
  busy,
  alreadyCalling,
  unavailable,
  microphone,
  failed,
}

final class CallState extends Equatable {
  const CallState({
    required this.phase,
    this.end,
    this.muted = false,
    this.speaker = false,
    this.seconds = 0,
  });

  final CallPhase phase;

  /// Why it ended, once [phase] is [CallPhase.ended].
  final CallEnd? end;
  final bool muted;
  final bool speaker;

  /// How long the call has been connected.
  final int seconds;

  CallState copyWith({
    CallPhase? phase,
    CallEnd? end,
    bool? muted,
    bool? speaker,
    int? seconds,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      end: end ?? this.end,
      muted: muted ?? this.muted,
      speaker: speaker ?? this.speaker,
      seconds: seconds ?? this.seconds,
    );
  }

  @override
  List<Object?> get props => [phase, end, muted, speaker, seconds];
}
