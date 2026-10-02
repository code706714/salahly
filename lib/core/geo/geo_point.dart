import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A WGS84 coordinate.
final class GeoPoint extends Equatable {
  const GeoPoint({required this.lat, required this.lng});

  final double lat;
  final double lng;

  static const _earthRadiusKm = 6371.0;

  /// Great-circle distance to [other] in kilometers.
  double distanceKmTo(GeoPoint other) {
    final dLat = _radians(other.lat - lat);
    final dLng = _radians(other.lng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(other.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.sqrt(a));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  List<Object?> get props => [lat, lng];
}
