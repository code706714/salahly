part of 'request_cubit.dart';

enum RequestLoadStatus { loading, ready, missing, failed }

/// What the consumer is doing to the request right now.
enum RequestAction {
  acceptOffer,
  counterOffer,
  cancel,
  widenWindow,
  approvePrice,
  declinePrice,
  review,
}

final class RequestState extends Equatable {
  const RequestState({
    this.status = RequestLoadStatus.loading,
    this.details,
    this.busy,
    this.failure,
  });

  final RequestLoadStatus status;

  /// The request, once fetched; kept while a refresh fails.
  final RequestDetails? details;

  /// The action in progress, if any.
  final RequestAction? busy;

  /// Why the last action failed.
  final Failure? failure;

  RequestState copyWith({
    RequestLoadStatus? status,
    RequestDetails? details,
    RequestAction? Function()? busy,
    Failure? Function()? failure,
  }) {
    return RequestState(
      status: status ?? this.status,
      details: details ?? this.details,
      busy: busy != null ? busy() : this.busy,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, details, busy, failure];
}
