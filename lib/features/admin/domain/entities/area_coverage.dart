import 'package:equatable/equatable.dart';

/// One service area with how well the platform covers it.
final class AreaCoverage extends Equatable {
  const AreaCoverage({
    required this.id,
    required this.name,
    required this.city,
    required this.isOpen,
    required this.verifiedTechnicians,
    required this.requests,
    required this.adsActive,
    this.gotOfferPercent,
  });

  final String id;
  final String name;
  final String city;

  /// Whether the area takes new requests.
  final bool isOpen;
  final int verifiedTechnicians;

  /// Requests over the period asked for.
  final int requests;

  /// The share of those that got an offer; null when there were none.
  final int? gotOfferPercent;

  /// Whether ads run here: the area is open and has enough technicians.
  final bool adsActive;

  @override
  List<Object?> get props => [
    id,
    name,
    city,
    isOpen,
    verifiedTechnicians,
    requests,
    gotOfferPercent,
    adsActive,
  ];
}

/// The areas, with the number of verified technicians that turns ads on.
final class AreaCoverageReport extends Equatable {
  const AreaCoverageReport({
    required this.areas,
    required this.adsMinTechnicians,
  });

  final List<AreaCoverage> areas;
  final int adsMinTechnicians;

  @override
  List<Object?> get props => [areas, adsMinTechnicians];
}
