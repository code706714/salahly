import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';

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

/// The catalog as seeded: air conditioning open, the rest coming soon.
abstract final class TestCategories {
  static const airConditioning = ServiceCategory(
    id: 'ac',
    name: 'تكييف',
    isActive: true,
    services: [
      CatalogService(
        id: 'ac_inspection',
        name: 'كشف',
        suggestedPricePiastres: 15000,
      ),
      CatalogService(
        id: 'ac_inspection_cleaning',
        name: 'كشف وتنظيف',
        suggestedPricePiastres: 35000,
      ),
      CatalogService(
        id: 'ac_freon_recharge',
        name: 'شحن فريون',
        suggestedPricePiastres: 65000,
      ),
    ],
    issues: [
      CatalogIssue(id: 'not_cooling', name: 'مش بيبرّد'),
      CatalogIssue(id: 'leaking', name: 'بينقّط مية'),
      CatalogIssue(id: 'noisy', name: 'صوته عالي'),
      CatalogIssue(id: 'needs_cleaning', name: 'محتاج تنضيف'),
      CatalogIssue(id: 'installation', name: 'تركيب أو نقل'),
      CatalogIssue(id: 'other', name: 'حاجة تانية'),
    ],
  );

  /// An open trade with its own services and problems.
  static const plumbing = ServiceCategory(
    id: 'plumbing',
    name: 'سباكة',
    isActive: true,
    services: [
      CatalogService(
        id: 'plumbing_inspection',
        name: 'كشف وتحديد العطل',
        suggestedPricePiastres: 15000,
      ),
      CatalogService(
        id: 'plumbing_leak_repair',
        name: 'إصلاح تسريب مية',
        suggestedPricePiastres: 25000,
      ),
    ],
    issues: [
      CatalogIssue(id: 'plumbing_leak', name: 'تسريب مية'),
      CatalogIssue(id: 'plumbing_clog', name: 'الصرف مسدود'),
      CatalogIssue(id: 'other', name: 'حاجة تانية'),
    ],
  );

  static const List<ServiceCategory> all = [
    airConditioning,
    ServiceCategory(
      id: 'electrical',
      name: 'كهربا',
      isActive: false,
      services: [],
    ),
    ServiceCategory(
      id: 'plumbing',
      name: 'سباكة',
      isActive: false,
      services: [],
    ),
    ServiceCategory(
      id: 'appliances',
      name: 'غسالات وتلاجات',
      isActive: false,
      services: [],
    ),
  ];
}
