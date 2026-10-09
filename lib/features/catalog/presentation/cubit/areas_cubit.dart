import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';

/// The service areas, for showing area names and picking an area.
class AreasCubit extends Cubit<AreasState> {
  AreasCubit(this._catalog) : super(const AreasState());

  final CatalogRepository _catalog;
  bool _loading = false;

  /// Fetches the areas unless they are already here.
  Future<void> load() async {
    if (state.areas.isNotEmpty || _loading) return;
    _loading = true;
    final result = await _catalog.fetchAreas();
    _loading = false;
    if (isClosed) return;
    if (result case Ok(:final value)) emit(AreasState(areas: value));
  }
}

final class AreasState extends Equatable {
  const AreasState({this.areas = const []});

  /// In display order; empty until fetched.
  final List<ServiceArea> areas;

  String? nameOf(String? areaId) {
    if (areaId == null) return null;
    for (final area in areas) {
      if (area.id == areaId) return area.name;
    }
    return null;
  }

  @override
  List<Object?> get props => [areas];
}
