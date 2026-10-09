import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'arrival_state.dart';

/// The technician's "قربت أوصل" button on a platform job: tells the
/// consumer he is almost there. It needs the internet and is never queued:
/// either the consumer was told or the technician sees why not.
class ArrivalCubit extends Cubit<ArrivalState> {
  ArrivalCubit({required this._requests, required this._jobId})
    : super(const ArrivalState());

  final TechnicianRequestsRepository _requests;
  final String _jobId;

  /// Finds out whether the consumer was told already (the page was opened
  /// again). A failure changes nothing: the button simply stays tappable.
  Future<void> load() async {
    final result = await _requests.fetchJobRequest(_jobId);
    if (isClosed) return;
    if (result case Ok(value: final link?)) {
      emit(
        state.copyWith(
          requestId: link.requestId,
          sentAt: link.arrivingSentAt,
        ),
      );
    }
  }

  /// Tells the consumer. Does nothing while sending or once told.
  Future<void> send() async {
    if (state.isSending || state.isSent) return;
    emit(state.copyWith(isSending: true, failure: () => null));
    final requestId = state.requestId ?? await _findRequest();
    if (isClosed) return;
    if (requestId == null) {
      emit(state.copyWith(isSending: false));
      return;
    }
    final result = await _requests.sendArriving(requestId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final at) => state.copyWith(isSending: false, sentAt: at),
      Err(:final failure) => state.copyWith(
        isSending: false,
        failure: () => failure,
      ),
    });
  }

  /// The request behind the job; on failure the state says why and this is
  /// null.
  Future<String?> _findRequest() async {
    final result = await _requests.fetchJobRequest(_jobId);
    if (isClosed) return null;
    switch (result) {
      case Ok(value: final link?):
        emit(state.copyWith(requestId: link.requestId));
        return link.requestId;
      case Ok():
        emit(state.copyWith(failure: () => const MarketplaceNotFoundFailure()));
      case Err(:final failure):
        emit(state.copyWith(failure: () => failure));
    }
    return null;
  }
}
