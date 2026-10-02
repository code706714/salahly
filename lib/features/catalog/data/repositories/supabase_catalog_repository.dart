import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/catalog/data/models/catalog_models.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<ServiceCategory>>> fetchCategories() async {
    try {
      final rows = await _client
          .from('service_categories')
          .select(ServiceCategoryModel.select)
          .order('sort_order');
      return Ok(rows.map(ServiceCategoryModel.fromJson).toList());
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }

  @override
  Future<Result<List<ServiceArea>>> fetchAreas() async {
    try {
      final rows = await _client
          .from('service_areas')
          .select(ServiceAreaModel.select)
          .eq('is_open', true)
          .order('sort_order');
      return Ok(rows.map(ServiceAreaModel.fromJson).toList());
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }
}
