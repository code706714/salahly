part of 'my_requests_cubit.dart';

enum MyRequestsStatus { loading, ready, failed }

final class MyRequestsState extends Equatable {
  const MyRequestsState({
    this.status = MyRequestsStatus.loading,
    this.requests = const [],
    this.failure,
  });

  final MyRequestsStatus status;

  /// Newest first.
  final List<RequestSummary> requests;

  /// Why the last fetch failed, while an older list stays shown.
  final Failure? failure;

  /// Requests still in progress: "شغالة دلوقتي".
  List<RequestSummary> get active =>
      requests.where((request) => request.stage.isActive).toList();

  /// Finished, cancelled and expired requests: "اللي فات".
  List<RequestSummary> get past =>
      requests.where((request) => !request.stage.isActive).toList();

  @override
  List<Object?> get props => [status, requests, failure];
}
