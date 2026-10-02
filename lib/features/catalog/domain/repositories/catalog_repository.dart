import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';

abstract interface class CatalogRepository {
  /// All categories in display order, each with its active services.
  Future<Result<List<ServiceCategory>>> fetchCategories();

  /// All areas in display order.
  Future<Result<List<ServiceArea>>> fetchAreas();
}
