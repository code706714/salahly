import 'package:equatable/equatable.dart';
import 'package:salahly/core/geo/geo_point.dart';

/// Everything a technician fills in. Photo fields are files on the device;
/// [TechnicianDocuments] holds the same photos once uploaded.
final class TechnicianOnboarding extends Equatable {
  const TechnicianOnboarding({
    required this.fullName,
    required this.shopName,
    required this.yearsExperience,
    required this.baseAreaId,
    required this.baseLocation,
    required this.serviceRadiusKm,
    required this.workDays,
    required this.areaIds,
    required this.startingPricesPiastres,
    required this.photos,
  });

  final String fullName;
  final String? shopName;
  final int yearsExperience;
  final String baseAreaId;
  final GeoPoint baseLocation;
  final int serviceRadiusKm;

  /// ISO weekdays: 1 = Monday ... 6 = Saturday, 7 = Sunday.
  final Set<int> workDays;
  final Set<String> areaIds;

  /// Service id to the technician's starting price.
  final Map<String, int> startingPricesPiastres;
  final TechnicianDocuments photos;

  @override
  List<Object?> get props => [
    fullName,
    shopName,
    yearsExperience,
    baseAreaId,
    baseLocation,
    serviceRadiusKm,
    workDays,
    areaIds,
    startingPricesPiastres,
    photos,
  ];
}

/// The profile photo and the three ID photos, as local file paths before
/// upload or storage paths after.
final class TechnicianDocuments extends Equatable {
  const TechnicianDocuments({
    required this.avatar,
    required this.idFront,
    required this.idBack,
    required this.selfieWithId,
  });

  final String avatar;
  final String idFront;
  final String idBack;
  final String selfieWithId;

  @override
  List<Object?> get props => [avatar, idFront, idBack, selfieWithId];
}
