import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';

/// What a user list can be narrowed to. Technicians have [verified],
/// [pending], [rejected] and [suspended]; customers [active] and
/// [suspended].
enum AccountStatus { verified, pending, rejected, active, suspended }

/// The statuses a list of [role] can be narrowed to.
List<AccountStatus> accountStatusesOf(UserRole role) => switch (role) {
  UserRole.technician => const [
    AccountStatus.verified,
    AccountStatus.pending,
    AccountStatus.rejected,
    AccountStatus.suspended,
  ],
  UserRole.consumer => const [AccountStatus.active, AccountStatus.suspended],
};

/// A person with an account: a technician or a customer.
sealed class AdminUser extends Equatable {
  const AdminUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.areaId,
    required this.areaName,
    required this.status,
    required this.balance,
    required this.pendingTopup,
    required this.createdAt,
    this.suspensionReason,
    this.lastSignInAt,
  });

  final String id;
  final String name;

  /// In international form.
  final String phone;
  final String areaId;
  final String areaName;
  final AccountStatus status;

  /// What they have left of paid and free uses.
  final int balance;

  /// Whether a transfer of theirs waits for review.
  final bool pendingTopup;
  final DateTime createdAt;
  final DateTime? lastSignInAt;

  /// Why the team suspended them, when they are suspended.
  final String? suspensionReason;

  bool get isSuspended => status == AccountStatus.suspended;

  UserRole get role;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    areaId,
    areaName,
    status,
    balance,
    pendingTopup,
    createdAt,
    lastSignInAt,
    suspensionReason,
  ];
}

final class AdminTechnician extends AdminUser {
  const AdminTechnician({
    required super.id,
    required super.name,
    required super.phone,
    required super.areaId,
    required super.areaName,
    required super.status,
    required super.balance,
    required super.pendingTopup,
    required super.createdAt,
    required this.verificationStatus,
    required this.reviewCount,
    required this.platformJobs,
    super.suspensionReason,
    super.lastSignInAt,
    this.rating,
  });

  /// Where their ID check stands, whether or not they are suspended.
  final VerificationStatus verificationStatus;

  /// The average of their reviews; null when they have none.
  final double? rating;
  final int reviewCount;

  /// Jobs customers chose them for on the platform.
  final int platformJobs;

  @override
  UserRole get role => UserRole.technician;

  @override
  List<Object?> get props => [
    ...super.props,
    verificationStatus,
    rating,
    reviewCount,
    platformJobs,
  ];
}

final class AdminConsumer extends AdminUser {
  const AdminConsumer({
    required super.id,
    required super.name,
    required super.phone,
    required super.areaId,
    required super.areaName,
    required super.status,
    required super.balance,
    required super.pendingTopup,
    required super.createdAt,
    required this.requestsCount,
    required this.complaintsCount,
    super.suspensionReason,
    super.lastSignInAt,
    this.lastRequestAt,
  });

  final int requestsCount;
  final DateTime? lastRequestAt;
  final int complaintsCount;

  @override
  UserRole get role => UserRole.consumer;

  @override
  List<Object?> get props => [
    ...super.props,
    requestsCount,
    lastRequestAt,
    complaintsCount,
  ];
}

/// What the users list is narrowed to.
final class UserFilter extends Equatable {
  const UserFilter({
    this.role = UserRole.technician,
    this.search = '',
    this.areaId,
    this.status,
  });

  final UserRole role;

  /// Part of a name or a phone.
  final String search;
  final String? areaId;
  final AccountStatus? status;

  /// Switching role drops the status, which may not exist for the other one.
  UserFilter withRole(UserRole role) =>
      UserFilter(role: role, search: search, areaId: areaId);

  UserFilter copyWith({
    String? search,
    String? Function()? areaId,
    AccountStatus? Function()? status,
  }) {
    return UserFilter(
      role: role,
      search: search ?? this.search,
      areaId: areaId != null ? areaId() : this.areaId,
      status: status != null ? status() : this.status,
    );
  }

  @override
  List<Object?> get props => [role, search, areaId, status];
}
