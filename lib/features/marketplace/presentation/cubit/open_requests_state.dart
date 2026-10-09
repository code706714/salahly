part of 'open_requests_cubit.dart';

enum OpenRequestsStatus { loading, ready, failed }

final class OpenRequestsState extends Equatable {
  const OpenRequestsState({
    this.status = OpenRequestsStatus.loading,
    this.requests = const [],
    this.categoryId,
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final OpenRequestsStatus status;
  final List<IncomingRequest> requests;

  /// The trade shown; null for all.
  final String? categoryId;

  /// The last page was full, so there may be more.
  final bool hasMore;
  final bool loadingMore;

  /// Why the last fetch failed.
  final Failure? failure;

  OpenRequestsState copyWith({
    OpenRequestsStatus? status,
    List<IncomingRequest>? requests,
    String? Function()? categoryId,
    bool? hasMore,
    bool? loadingMore,
    Failure? Function()? failure,
  }) {
    return OpenRequestsState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    requests,
    categoryId,
    hasMore,
    loadingMore,
    failure,
  ];
}
