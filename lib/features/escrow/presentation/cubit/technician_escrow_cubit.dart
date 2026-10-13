import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';

/// Whether the consumer's money for a request is secured; null while
/// unknown or when she did not pay in.
class TechnicianEscrowCubit extends Cubit<TechnicianEscrow?> {
  TechnicianEscrowCubit({required this._escrow, required this._requestId})
    : super(null);

  final EscrowRepository _escrow;
  final String _requestId;

  /// Fetches the payment. It is an extra on the screen, so a failed fetch
  /// keeps what is shown.
  Future<void> load() async {
    final result = await _escrow.fetchTechnicianEscrow(_requestId);
    if (isClosed) return;
    if (result case Ok(:final value)) emit(value);
  }
}
