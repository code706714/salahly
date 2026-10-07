import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

/// A pack of uses on sale, or switched off.
final class CreditPackSetting extends Equatable {
  const CreditPackSetting({
    required this.id,
    required this.role,
    required this.uses,
    required this.pricePiastres,
    required this.sortOrder,
    required this.isActive,
  });

  final String id;

  /// Who can buy it.
  final UserRole role;
  final int uses;
  final int pricePiastres;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    role,
    uses,
    pricePiastres,
    sortOrder,
    isActive,
  ];
}

/// A pack the team is adding or changing.
final class CreditPackDraft extends Equatable {
  const CreditPackDraft({
    required this.role,
    required this.uses,
    required this.pricePiastres,
    this.id,
    this.sortOrder = 0,
    this.isActive = true,
  });

  /// Null for a new pack.
  final String? id;
  final UserRole role;
  final int uses;
  final int pricePiastres;
  final int sortOrder;
  final bool isActive;

  @override
  List<Object?> get props => [
    id,
    role,
    uses,
    pricePiastres,
    sortOrder,
    isActive,
  ];
}

/// Where people send money for a method, and whether it is offered.
final class PaymentAccountSetting extends Equatable {
  const PaymentAccountSetting({
    required this.method,
    required this.account,
    required this.holderName,
    required this.isActive,
  });

  final TopupMethod method;

  /// The InstaPay address or the wallet's mobile number.
  final String account;
  final String holderName;
  final bool isActive;

  @override
  List<Object?> get props => [method, account, holderName, isActive];
}

/// What the settings page shows, except the areas.
final class AdminSettings extends Equatable {
  const AdminSettings({
    required this.consumerFreeRequests,
    required this.technicianFreeJobs,
    required this.verifiedTechnicianTarget,
    required this.packs,
    required this.paymentAccounts,
  });

  /// Free requests a new customer gets.
  final int consumerFreeRequests;

  /// Free jobs a new technician gets.
  final int technicianFreeJobs;

  /// The number of verified technicians the launch waits for.
  final int verifiedTechnicianTarget;

  /// Every pack, including the ones switched off.
  final List<CreditPackSetting> packs;
  final List<PaymentAccountSetting> paymentAccounts;

  List<CreditPackSetting> packsOf(UserRole role) => [
    for (final pack in packs)
      if (pack.role == role) pack,
  ];

  @override
  List<Object?> get props => [
    consumerFreeRequests,
    technicianFreeJobs,
    verifiedTechnicianTarget,
    packs,
    paymentAccounts,
  ];
}

/// An area the team is adding or changing.
final class AreaDraft extends Equatable {
  const AreaDraft({
    required this.id,
    required this.name,
    required this.city,
    required this.centerLat,
    required this.centerLng,
    this.isOpen = true,
  });

  /// Lower case letters, digits and `_`, starting with a letter.
  final String id;
  final String name;
  final String city;
  final double centerLat;
  final double centerLng;
  final bool isOpen;

  @override
  List<Object?> get props => [id, name, city, centerLat, centerLng, isOpen];
}
