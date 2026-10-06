import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'incoming_requests_state.dart';

/// The requests sent to the technician, shared by "النهارده" and the
/// requests list.
///
/// The server lists only the requests still waiting for this technician's
/// offer. Requests the technician opened stay in the list for the session
/// with what happened to them (their offer, or that the request closed),
/// until their time is over.
class IncomingRequestsCubit extends Cubit<IncomingRequestsState> {
  IncomingRequestsCubit(this._requests, {this._clock = DateTime.now})
    : super(const IncomingRequestsState());

  final TechnicianRequestsRepository _requests;
  final DateTime Function() _clock;
  late final _fetch = SingleFlight(_fetchRequests);

  /// Fetches the new requests again. A failed refresh keeps the list shown.
  Future<void> fetchNewRequests() => _fetch();

  Future<void> _fetchRequests() async {
    final result = await _requests.fetchNewRequests();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(_merged(value));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.status == IncomingRequestsStatus.ready
                ? IncomingRequestsStatus.ready
                : IncomingRequestsStatus.failed,
            failure: () => failure,
          ),
        );
    }
  }

  /// The server's [fresh] list, plus the requests already shown that it no
  /// longer lists: those got an offer from this technician or closed.
  IncomingRequestsState _merged(List<IncomingRequest> fresh) {
    final now = _clock();
    final known = {for (final request in state.requests) request.id: request};
    final freshIds = {for (final request in fresh) request.id};
    final requests = [
      for (final request in fresh)
        // An offer sent while this list was on its way.
        if (known[request.id] case final shown? when shown.myOffer != null)
          shown
        else
          request,
      for (final request in state.requests)
        if (!freshIds.contains(request.id) && request.expiresAt.isAfter(now))
          request,
    ];
    return IncomingRequestsState(
      status: IncomingRequestsStatus.ready,
      requests: _newestFirst(requests),
      closedIds: {
        for (final request in requests)
          if (!freshIds.contains(request.id) && request.acceptsOffers)
            request.id,
      },
    );
  }

  /// Puts [request] in the list as its own page last fetched it. A
  /// dismissed request leaves the list.
  void updateRequest(IncomingRequest request) {
    final others = state.requests.where((shown) => shown.id != request.id);
    emit(
      state.copyWith(
        requests: _newestFirst([...others, if (!request.dismissed) request]),
        closedIds: {...state.closedIds}..remove(request.id),
      ),
    );
  }

  static List<IncomingRequest> _newestFirst(List<IncomingRequest> requests) =>
      requests..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}
