part of 'incoming_requests_cubit.dart';

enum IncomingRequestsStatus { loading, ready, failed }

final class IncomingRequestsState extends Equatable {
  const IncomingRequestsState({
    this.status = IncomingRequestsStatus.loading,
    this.requests = const [],
    this.closedIds = const {},
    this.failure,
  });

  final IncomingRequestsStatus status;

  /// Newest first.
  final List<IncomingRequest> requests;

  /// Requests the server stopped listing although they looked open here:
  /// they closed (picked, cancelled, expired or full) since.
  final Set<String> closedIds;

  /// Why the last fetch failed, while an older list stays shown.
  final Failure? failure;

  /// Whether this technician can still send an offer on [request].
  bool acceptsOffers(IncomingRequest request) =>
      request.acceptsOffers && !closedIds.contains(request.id);

  /// Requests still waiting for this technician's offer.
  List<IncomingRequest> get newRequests => [
    for (final request in requests)
      if (!request.dismissed && acceptsOffers(request)) request,
  ];

  IncomingRequestsState copyWith({
    IncomingRequestsStatus? status,
    List<IncomingRequest>? requests,
    Set<String>? closedIds,
    Failure? Function()? failure,
  }) {
    return IncomingRequestsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      closedIds: closedIds ?? this.closedIds,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, requests, closedIds, failure];
}
