import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';

final class UserProfile extends Equatable {
  const UserProfile({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.activeRole,
    this.consumer,
    this.technician,
  });

  final String id;

  /// E.164, e.g. +201002345678.
  final String phone;
  final String fullName;
  final UserRole activeRole;
  final ConsumerProfile? consumer;
  final TechnicianProfile? technician;

  String get firstName => fullName.split(' ').first;

  @override
  List<Object?> get props => [
    id,
    phone,
    fullName,
    activeRole,
    consumer,
    technician,
  ];
}

final class ConsumerProfile extends Equatable {
  const ConsumerProfile({
    required this.honorific,
    required this.areaId,
    required this.areaName,
    required this.requestCredits,
  });

  final Honorific honorific;

  /// The area picked at sign-up.
  final String areaId;
  final String areaName;

  /// Requests the consumer can still send without paying.
  final int requestCredits;

  @override
  List<Object?> get props => [honorific, areaId, areaName, requestCredits];
}

final class TechnicianProfile extends Equatable {
  const TechnicianProfile({
    required this.verificationStatus,
    required this.jobCredits,
  });

  final VerificationStatus verificationStatus;

  /// Platform jobs the technician can still take without paying.
  final int jobCredits;

  @override
  List<Object?> get props => [verificationStatus, jobCredits];
}
