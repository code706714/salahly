import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';

/// A technician's ID submission, as a row of the queue.
final class VerificationSummary extends Equatable {
  const VerificationSummary({
    required this.verificationId,
    required this.technicianId,
    required this.name,
    required this.areaId,
    required this.areaName,
    required this.status,
    required this.submittedAt,
    required this.suspended,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String verificationId;
  final String technicianId;
  final String name;
  final String areaId;
  final String areaName;
  final VerificationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final bool suspended;

  @override
  List<Object?> get props => [
    verificationId,
    technicianId,
    name,
    areaId,
    areaName,
    status,
    submittedAt,
    reviewedAt,
    rejectionReason,
    suspended,
  ];
}

/// An area a technician works in.
final class NamedArea extends Equatable {
  const NamedArea({required this.id, required this.name});

  final String id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// A service a technician offers, with the price they start from.
final class OfferedService extends Equatable {
  const OfferedService({
    required this.serviceId,
    required this.name,
    required this.startingPricePiastres,
  });

  final String serviceId;
  final String name;
  final int startingPricePiastres;

  @override
  List<Object?> get props => [serviceId, name, startingPricePiastres];
}

/// Everything the reviewer checks about one submission.
///
/// The three photo paths are in the `verification-docs` bucket; the reviewer
/// opens them with a short-lived signed link.
final class VerificationDetail extends Equatable {
  const VerificationDetail({
    required this.verificationId,
    required this.technicianId,
    required this.status,
    required this.submittedAt,
    required this.idFrontPath,
    required this.idBackPath,
    required this.selfiePath,
    required this.name,
    required this.phone,
    required this.phoneConfirmed,
    required this.yearsExperience,
    required this.area,
    required this.serviceRadiusKm,
    required this.workDays,
    required this.suspended,
    required this.previousAttempts,
    required this.areas,
    required this.services,
    this.reviewedAt,
    this.rejectionReason,
    this.shopName,
  });

  final String verificationId;
  final String technicianId;
  final VerificationStatus status;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final String idFrontPath;
  final String idBackPath;
  final String selfiePath;
  final String name;

  /// The account's phone in international form, as the server keeps it.
  final String phone;

  /// Whether the phone was confirmed with a code.
  final bool phoneConfirmed;
  final String? shopName;
  final int yearsExperience;

  /// Where the technician is based.
  final NamedArea area;
  final int serviceRadiusKm;

  /// The days they work, as [DateTime.weekday] numbers.
  final Set<int> workDays;
  final bool suspended;

  /// How many earlier submissions this technician made.
  final int previousAttempts;

  /// The other areas they cover.
  final List<NamedArea> areas;
  final List<OfferedService> services;

  bool get isPending => status == VerificationStatus.pending;

  @override
  List<Object?> get props => [
    verificationId,
    technicianId,
    status,
    submittedAt,
    reviewedAt,
    rejectionReason,
    idFrontPath,
    idBackPath,
    selfiePath,
    name,
    phone,
    phoneConfirmed,
    shopName,
    yearsExperience,
    area,
    serviceRadiusKm,
    workDays,
    suspended,
    previousAttempts,
    areas,
    services,
  ];
}
