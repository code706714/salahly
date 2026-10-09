import 'package:equatable/equatable.dart';

/// A trade the platform covers, e.g. تكييف, with its services.
final class ServiceCategory extends Equatable {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.services,
    this.issues = const [],
  });

  final String id;
  final String name;

  /// Inactive categories show as "coming soon".
  final bool isActive;
  final List<CatalogService> services;

  /// What a consumer can say is wrong in this trade, in display order;
  /// ends with "other".
  final List<CatalogIssue> issues;

  @override
  List<Object?> get props => [id, name, isActive, services, issues];
}

/// A problem a consumer can pick for a trade.
final class CatalogIssue extends Equatable {
  const CatalogIssue({required this.id, required this.name});

  /// The server's name for the problem: `not_cooling`.
  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
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
