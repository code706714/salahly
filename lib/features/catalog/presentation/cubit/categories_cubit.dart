import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';

/// The service categories with their services, for names and choices.
class CategoriesCubit extends Cubit<CategoriesState> {
  CategoriesCubit(this._catalog) : super(const CategoriesState());

  final CatalogRepository _catalog;
  bool _loading = false;

  /// Fetches the categories unless they are already here.
  Future<void> load() async {
    if (state.categories.isNotEmpty || _loading) return;
    _loading = true;
    if (state.failed) emit(const CategoriesState());
    final result = await _catalog.fetchCategories();
    _loading = false;
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(CategoriesState(categories: value));
      case Err():
        emit(const CategoriesState(failed: true));
    }
  }
}

final class CategoriesState extends Equatable {
  const CategoriesState({this.categories = const [], this.failed = false});

  /// In display order; empty until fetched.
  final List<ServiceCategory> categories;

  /// The last fetch failed, so a screen that needs the list can say so and
  /// offer to try again.
  final bool failed;

  ServiceCategory? category(String? id) =>
      categories.where((category) => category.id == id).firstOrNull;

  String? serviceName(String? serviceId) {
    for (final category in categories) {
      for (final service in category.services) {
        if (service.id == serviceId) return service.name;
      }
    }
    return null;
  }

  @override
  List<Object?> get props => [categories, failed];
}
