import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';

abstract final class ServiceCategoryModel {
  static const select =
      'id, name_ar, is_active, sort_order, '
      'services(id, name_ar, suggested_price_piastres, is_active, sort_order), '
      'category_issues(issue, name_ar, sort_order)';

  static ServiceCategory fromJson(Map<String, dynamic> json) {
    final services =
        (json['services'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .where((service) => service['is_active'] as bool)
            .toList()
          ..sort(_bySortOrder);
    final issues =
        (json['category_issues'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .toList()
          ..sort(_bySortOrder);
    return ServiceCategory(
      id: json['id'] as String,
      name: json['name_ar'] as String,
      isActive: json['is_active'] as bool,
      services: [
        for (final service in services)
          CatalogService(
            id: service['id'] as String,
            name: service['name_ar'] as String,
            suggestedPricePiastres: service['suggested_price_piastres'] as int,
          ),
      ],
      issues: [
        for (final issue in issues)
          CatalogIssue(
            id: issue['issue'] as String,
            name: issue['name_ar'] as String,
          ),
      ],
    );
  }

  static int _bySortOrder(Map<String, dynamic> a, Map<String, dynamic> b) =>
      (a['sort_order'] as int).compareTo(b['sort_order'] as int);
}

abstract final class ServiceAreaModel {
  static const select = 'id, name_ar, city_ar, center_lat, center_lng';

  static ServiceArea fromJson(Map<String, dynamic> json) {
    return ServiceArea(
      id: json['id'] as String,
      name: json['name_ar'] as String,
      city: json['city_ar'] as String,
      center: GeoPoint(
        lat: (json['center_lat'] as num).toDouble(),
        lng: (json['center_lng'] as num).toDouble(),
      ),
    );
  }
}
