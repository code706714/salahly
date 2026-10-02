import 'package:geolocator/geolocator.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/core/location/location_service.dart';

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<Result<GeoPoint>> approximatePosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err(LocationDisabledFailure());
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          return const Err(LocationPermissionFailure(permanently: false));
        case LocationPermission.deniedForever:
          return const Err(LocationPermissionFailure(permanently: true));
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return Ok(GeoPoint(lat: position.latitude, lng: position.longitude));
    } on Object catch (error) {
      return Err(UnexpectedFailure(error));
    }
  }
}
