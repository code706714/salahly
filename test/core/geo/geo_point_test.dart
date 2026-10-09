import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/geo/geo_point.dart';

void main() {
  const tahrirSquare = GeoPoint(lat: 30.0444, lng: 31.2357);
  const gizaPyramids = GeoPoint(lat: 29.9792, lng: 31.1342);
  const alexandria = GeoPoint(lat: 31.2001, lng: 29.9187);

  group('GeoPoint.distanceKmTo', () {
    test('is zero from a point to itself', () {
      expect(tahrirSquare.distanceKmTo(tahrirSquare), 0);
    });

    test('measures Tahrir Square to the Giza Pyramids as about 12.2 km', () {
      expect(tahrirSquare.distanceKmTo(gizaPyramids), closeTo(12.17, 0.01));
    });

    test('measures Cairo to Alexandria as about 180 km', () {
      expect(tahrirSquare.distanceKmTo(alexandria), closeTo(179.98, 0.01));
    });

    test('measures one degree of latitude as about 111.2 km', () {
      const origin = GeoPoint(lat: 0, lng: 0);
      const north = GeoPoint(lat: 1, lng: 0);

      expect(origin.distanceKmTo(north), closeTo(111.19, 0.01));
    });

    test('measures antipodal points as half the Earth circumference', () {
      const origin = GeoPoint(lat: 0, lng: 0);
      const antipode = GeoPoint(lat: 0, lng: 180);

      expect(origin.distanceKmTo(antipode), closeTo(math.pi * 6371, 1e-6));
    });

    test('is symmetric', () {
      expect(
        gizaPyramids.distanceKmTo(alexandria),
        alexandria.distanceKmTo(gizaPyramids),
      );
    });
  });

  test('points with the same coordinates are equal', () {
    expect(
      const GeoPoint(lat: 30.0444, lng: 31.2357),
      tahrirSquare,
    );
  });
}
