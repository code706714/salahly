part of 'technician_escrow_cubit.dart';

final class TechnicianEscrowState extends Equatable {
  const TechnicianEscrowState({this.escrow, this.busy = false, this.failure});

  /// Null while unknown or when the consumer did not pay in.
  final TechnicianEscrow? escrow;

  /// His answer is on its way.
  final bool busy;

  /// Why the last answer was not taken.
  final Failure? failure;

  TechnicianEscrowState copyWith({
    TechnicianEscrow? Function()? escrow,
    bool? busy,
    Failure? Function()? failure,
  }) {
    return TechnicianEscrowState(
      escrow: escrow != null ? escrow() : this.escrow,
      busy: busy ?? this.busy,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [escrow, busy, failure];
}
