import 'package:equatable/equatable.dart';
import 'package:salahly/core/phone/phone_number.dart';

/// Where a customer record came from.
enum CustomerSource { manual, contacts, platform }

/// Someone the technician works for.
final class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    required this.createdAt,
    this.phone,
    this.areaId,
    this.address,
    this.notes,
    this.source = CustomerSource.manual,
  });

  final String id;

  /// As the technician wrote it, often with a title: "أ. كريم منصور".
  final String name;
  final PhoneNumber? phone;
  final String? areaId;
  final String? address;
  final String? notes;
  final CustomerSource source;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    areaId,
    address,
    notes,
    source,
    createdAt,
  ];
}

/// A customer's details as entered in the form, before saving.
final class CustomerDraft extends Equatable {
  const CustomerDraft({
    required this.name,
    this.phone,
    this.areaId,
    this.address,
    this.notes,
    this.source = CustomerSource.manual,
  });

  final String name;
  final PhoneNumber? phone;
  final String? areaId;
  final String? address;
  final String? notes;
  final CustomerSource source;

  @override
  List<Object?> get props => [name, phone, areaId, address, notes, source];
}
