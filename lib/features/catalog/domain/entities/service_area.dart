import 'package:equatable/equatable.dart';
import 'package:salahly/core/geo/geo_point.dart';

/// A district technicians cover, e.g. مدينة نصر.
final class ServiceArea extends Equatable {
  const ServiceArea({
    required this.id,
    required this.name,
    required this.city,
    required this.center,
  });

  final String id;
  final String name;
  final String city;
  final GeoPoint center;

  @override
  List<Object?> get props => [id, name, city, center];
}

/// Beyond this distance the nearest area is a guess, so the user picks.
const nearestAreaMaxKm = 25.0;

/// [areas] ordered from closest to farthest from [point].
List<ServiceArea> areasByDistance(List<ServiceArea> areas, GeoPoint point) {
  return [...areas]..sort(
    (a, b) =>
        a.center.distanceKmTo(point).compareTo(b.center.distanceKmTo(point)),
  );
}

/// The area containing [point], or null when no area is close enough.
ServiceArea? nearestArea(List<ServiceArea> areas, GeoPoint point) {
  if (areas.isEmpty) return null;
  final closest = areasByDistance(areas, point).first;
  return closest.center.distanceKmTo(point) <= nearestAreaMaxKm
      ? closest
      : null;
}
