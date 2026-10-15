import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';

part 'technician_escrow_state.dart';

/// The consumer's money for a request, as the picked technician sees it,
/// and his answer once the work is done.
class TechnicianEscrowCubit extends Cubit<TechnicianEscrowState> {
  TechnicianEscrowCubit({required this._escrow, required this._requestId})
    : super(const TechnicianEscrowState());

  final EscrowRepository _escrow;
  final String _requestId;

  /// Fetches the payment. It is an extra on the screen, so a failed fetch
  /// keeps what is shown.
  Future<void> load() async {
    final result = await _escrow.fetchTechnicianEscrow(_requestId);
    if (isClosed) return;
    if (result case Ok(:final value)) {
      emit(state.copyWith(escrow: () => value));
    }
  }

  /// The work is done and right.
  Future<void> confirm() =>
      _answer(() => _escrow.technicianConfirmWork(_requestId));

  /// Something is wrong: Salahly keeps the money and decides.
  Future<void> dispute(String reason) =>
      _answer(() => _escrow.technicianDispute(_requestId, reason));

  Future<void> _answer(Future<Result<void>> Function() action) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, failure: () => null));
    final result = await action();
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(busy: false));
      case Err(:final failure):
        emit(state.copyWith(busy: false, failure: () => failure));
    }
    await load();
  }
}
