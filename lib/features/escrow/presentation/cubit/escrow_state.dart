part of 'escrow_cubit.dart';

final class EscrowState extends Equatable {
  const EscrowState({
    this.loaded = false,
    this.info,
    this.busy = false,
    this.failure,
  });

  /// The first fetch finished, with or without an answer.
  final bool loaded;
  final EscrowInfo? info;

  /// The consumer's answer is on its way.
  final bool busy;

  /// Why the last answer was not taken.
  final Failure? failure;

  EscrowState copyWith({
    bool? loaded,
    EscrowInfo? Function()? info,
    bool? busy,
    Failure? Function()? failure,
  }) {
    return EscrowState(
      loaded: loaded ?? this.loaded,
      info: info != null ? info() : this.info,
      busy: busy ?? this.busy,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [loaded, info, busy, failure];
}
