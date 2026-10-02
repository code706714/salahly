import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';

const _downtown = ServiceArea(
  id: 'downtown',
  name: 'وسط البلد',
  city: 'القاهرة',
  center: GeoPoint(lat: 30.0444, lng: 31.2357),
);
const _nasrCity = ServiceArea(
  id: 'nasr-city',
  name: 'مدينة نصر',
  city: 'القاهرة',
  center: GeoPoint(lat: 30.0561, lng: 31.3301),
);
const _maadi = ServiceArea(
  id: 'maadi',
  name: 'المعادي',
  city: 'القاهرة',
  center: GeoPoint(lat: 29.9602, lng: 31.2569),
);
const _october = ServiceArea(
  id: 'october',
  name: '6 أكتوبر',
  city: 'الجيزة',
  center: GeoPoint(lat: 29.9285, lng: 30.9188),
);

const _heliopolis = GeoPoint(lat: 30.0911, lng: 31.3227);
const _fayoum = GeoPoint(lat: 29.3084, lng: 30.8428);

const double _kmPerDegreeOfLatitude = 6371 * math.pi / 180;

ServiceArea _areaNorthOf(GeoPoint point, double km) => ServiceArea(
  id: 'north-$km',
  name: 'منطقة',
  city: 'القاهرة',
  center: GeoPoint(
    lat: point.lat + km / _kmPerDegreeOfLatitude,
    lng: point.lng,
  ),
);

void main() {
  const areas = [_october, _maadi, _downtown, _nasrCity];

  group('areasByDistance', () {
    test('orders areas from closest to farthest', () {
      expect(
        areasByDistance(areas, _heliopolis),
        [_nasrCity, _downtown, _maadi, _october],
      );
    });

    test('leaves the given list in its original order', () {
      final given = [...areas];

      areasByDistance(given, _heliopolis);

      expect(given, areas);
    });

    test('returns an empty list for no areas', () {
      expect(areasByDistance(const [], _heliopolis), isEmpty);
    });
  });

  group('nearestArea', () {
    test('returns the closest area', () {
      expect(nearestArea(areas, _heliopolis), _nasrCity);
    });

    test('returns the area whose center is the point', () {
      expect(nearestArea(areas, _downtown.center), _downtown);
    });

    test('returns null when every area is farther than the cutoff', () {
      expect(nearestArea(areas, _fayoum), isNull);
    });

    test('returns null for no areas', () {
      expect(nearestArea(const [], _heliopolis), isNull);
    });

    test('accepts an area just inside the 25 km cutoff', () {
      const point = GeoPoint(lat: 30, lng: 31.2);
      final area = _areaNorthOf(point, nearestAreaMaxKm - 0.01);

      expect(nearestArea([area], point), area);
    });

    test('rejects an area just beyond the 25 km cutoff', () {
      const point = GeoPoint(lat: 30, lng: 31.2);
      final area = _areaNorthOf(point, nearestAreaMaxKm + 0.01);

      expect(nearestArea([area], point), isNull);
    });
  });
}
