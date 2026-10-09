import 'package:equatable/equatable.dart';

/// A trade the platform covers, e.g. تكييف, with its services.
final class ServiceCategory extends Equatable {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.services,
  });

  final String id;
  final String name;

  /// Inactive categories show as "coming soon".
  final bool isActive;
  final List<CatalogService> services;

  @override
  List<Object?> get props => [id, name, isActive, services];
}

final class CatalogService extends Equatable {
  const CatalogService({
    required this.id,
    required this.name,
    required this.suggestedPricePiastres,
  });

  final String id;
  final String name;
  final int suggestedPricePiastres;

  @override
  List<Object?> get props => [id, name, suggestedPricePiastres];
}
