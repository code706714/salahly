import 'package:equatable/equatable.dart';

/// An air conditioner at a customer's place.
final class CustomerUnit extends Equatable {
  const CustomerUnit({
    required this.id,
    required this.customerId,
    this.brand,
    this.capacityHp,
    this.room,
    this.installedYear,
    this.nextServiceOn,
  });

  static const minCapacityHp = 0.75;
  static const maxCapacityHp = 6.0;

  final String id;
  final String customerId;

  /// e.g. شارب, كارير.
  final String? brand;

  /// Horsepower, e.g. 1.5 or 2.25.
  final double? capacityHp;

  /// e.g. الصالة, أوضة النوم.
  final String? room;
  final int? installedYear;

  /// The next cleaning or service, a calendar date at local midnight.
  final DateTime? nextServiceOn;

  @override
  List<Object?> get props => [
    id,
    customerId,
    brand,
    capacityHp,
    room,
    installedYear,
    nextServiceOn,
  ];
}

/// A unit's details as entered in the form, before saving.
final class CustomerUnitDraft extends Equatable {
  const CustomerUnitDraft({
    this.brand,
    this.capacityHp,
    this.room,
    this.installedYear,
    this.nextServiceOn,
  });

  final String? brand;
  final double? capacityHp;
  final String? room;
  final int? installedYear;
  final DateTime? nextServiceOn;

  @override
  List<Object?> get props => [
    brand,
    capacityHp,
    room,
    installedYear,
    nextServiceOn,
  ];
}
