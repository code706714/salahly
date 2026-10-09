part of 'technician_directory_cubit.dart';

enum TechnicianDirectoryStatus { loading, ready, failed }

final class TechnicianDirectoryState extends Equatable {
  const TechnicianDirectoryState({
    this.status = TechnicianDirectoryStatus.loading,
    this.technicians = const [],
    this.categoryId,
    this.areaId,
    this.sort = TechnicianSort.rating,
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final TechnicianDirectoryStatus status;
  final List<TechnicianListing> technicians;

  /// The trade shown; null for all.
  final String? categoryId;

  /// The area they must cover; null for any.
  final String? areaId;
  final TechnicianSort sort;

  /// The last page was full, so there may be more.
  final bool hasMore;
  final bool loadingMore;

  /// Why the last fetch failed.
  final Failure? failure;

  TechnicianDirectoryState copyWith({
    TechnicianDirectoryStatus? status,
    List<TechnicianListing>? technicians,
    String? Function()? categoryId,
    String? Function()? areaId,
    TechnicianSort? sort,
    bool? hasMore,
    bool? loadingMore,
    Failure? Function()? failure,
  }) {
    return TechnicianDirectoryState(
      status: status ?? this.status,
      technicians: technicians ?? this.technicians,
      categoryId: categoryId != null ? categoryId() : this.categoryId,
      areaId: areaId != null ? areaId() : this.areaId,
      sort: sort ?? this.sort,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    technicians,
    categoryId,
    areaId,
    sort,
    hasMore,
    loadingMore,
    failure,
  ];
}
