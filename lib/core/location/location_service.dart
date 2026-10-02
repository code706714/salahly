import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';

/// The user refused location access. [permanently] means only the system
/// settings can grant it now.
final class LocationPermissionFailure extends Failure {
  const LocationPermissionFailure({required this.permanently});

  final bool permanently;

  @override
  List<Object?> get props => [permanently];
}

/// Location services are switched off on the device.
final class LocationDisabledFailure extends Failure {
  const LocationDisabledFailure();
}

// An interface so screens can be tested without a device location.
// ignore: one_member_abstracts
abstract interface class LocationService {
  /// An approximate position (city-block precision is enough for the app),
  /// asking for permission if needed.
  Future<Result<GeoPoint>> approximatePosition();
}
