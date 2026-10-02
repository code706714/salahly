import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';

/// Real areas from the catalog seed, with their production centers.
abstract final class TestAreas {
  static const nasrCity = ServiceArea(
    id: 'nasr_city',
    name: 'مدينة نصر',
    city: 'القاهرة',
    center: GeoPoint(lat: 30.0561, lng: 31.33),
  );

  static const heliopolis = ServiceArea(
    id: 'heliopolis',
    name: 'مصر الجديدة',
    city: 'القاهرة',
    center: GeoPoint(lat: 30.0911, lng: 31.3225),
  );

  static const maadi = ServiceArea(
    id: 'maadi',
    name: 'المعادي',
    city: 'القاهرة',
    center: GeoPoint(lat: 29.96, lng: 31.257),
  );

  static const zamalek = ServiceArea(
    id: 'zamalek',
    name: 'الزمالك',
    city: 'القاهرة',
    center: GeoPoint(lat: 30.061, lng: 31.22),
  );

  static const List<ServiceArea> all = [nasrCity, heliopolis, maadi, zamalek];
}

/// Device positions relative to [TestAreas].
abstract final class TestPositions {
  /// Under a kilometer from Maadi's center, and within 25 km of every
  /// other test area too.
  static const inMaadi = GeoPoint(lat: 29.9627, lng: 31.2496);

  /// Alexandria, far outside every Cairo area.
  static const alexandria = GeoPoint(lat: 31.2001, lng: 29.9187);
}
