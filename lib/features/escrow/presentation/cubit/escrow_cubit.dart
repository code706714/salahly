import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';

part 'escrow_state.dart';

/// The guarantee card of one request: where the payment stands, and the
/// consumer's answer once the work is done.
class EscrowCubit extends Cubit<EscrowState> {
  EscrowCubit({required this._escrow, required this._requestId})
    : super(const EscrowState());

  final EscrowRepository _escrow;
  final String _requestId;

  /// Fetches the payment. A failed refresh keeps what is shown.
  Future<void> load() async {
    final result = await _escrow.fetchInfo(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(info: () => value, loaded: true));
      case Err():
        // The guarantee is an extra: the screen works without it.
        emit(state.copyWith(loaded: true));
    }
  }

  /// The work is right: the money goes to the technician.
  Future<void> confirm() => _answer(() => _escrow.confirmWork(_requestId));

  /// Something is wrong with the work: Salahly keeps the money and decides.
  Future<void> dispute(String reason) =>
      _answer(() => _escrow.dispute(_requestId, reason));

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
