import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

/// What a technician offers: services with starting prices, where and on
/// which days. Replaced as a whole when edited.
final class TechnicianOffering extends Equatable {
  const TechnicianOffering({
    required this.services,
    required this.areaIds,
    required this.workDays,
    this.radiusKm,
  });

  final List<ServicePrice> services;
  final Set<String> areaIds;

  /// ISO weekdays: 1 = Monday ... 7 = Sunday.
  final Set<int> workDays;

  /// 5, 10 or 15.
  final int? radiusKm;

  @override
  List<Object?> get props => [
    services,
    areaIds,
    workDays,
    radiusKm,
  ];
}
