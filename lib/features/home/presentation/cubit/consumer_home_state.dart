part of 'consumer_home_cubit.dart';

final class ConsumerHomeState extends Equatable {
  const ConsumerHomeState({
    this.categories = const [],
    this.selectedId,
    this.technicianCounts = const {},
  });

  /// In display order; empty until the catalog arrives.
  final List<ServiceCategory> categories;

  /// The open category the request button asks for.
  final String? selectedId;

  /// Verified technicians covering the consumer's area, by category id,
  /// once counted.
  final Map<String, int> technicianCounts;

  ServiceCategory? get selected => category(selectedId);

  ServiceCategory? category(String? id) =>
      categories.where((category) => category.id == id).firstOrNull;

  ConsumerHomeState copyWith({
    List<ServiceCategory>? categories,
    String? Function()? selectedId,
    Map<String, int>? technicianCounts,
  }) {
    return ConsumerHomeState(
      categories: categories ?? this.categories,
      selectedId: selectedId != null ? selectedId() : this.selectedId,
      technicianCounts: technicianCounts ?? this.technicianCounts,
    );
  }

  @override
  List<Object?> get props => [categories, selectedId, technicianCounts];
}
