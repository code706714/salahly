import 'package:equatable/equatable.dart';

/// One thing an admin did, from the append-only audit log.
final class AuditEntry extends Equatable {
  const AuditEntry({
    required this.id,
    required this.adminId,
    required this.action,
    required this.targetType,
    required this.details,
    required this.createdAt,
    this.adminName,
    this.targetId,
  });

  final int id;

  /// Who did it. The name is null once their profile is gone.
  final String adminId;
  final String? adminName;

  /// What was done, like `approve_topup`.
  final String action;
  final String targetType;
  final String? targetId;

  /// What the action recorded, such as the reason typed.
  final Map<String, Object?> details;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    adminId,
    adminName,
    action,
    targetType,
    targetId,
    details,
    createdAt,
  ];
}

/// What the audit log is narrowed to.
final class AuditFilter extends Equatable {
  const AuditFilter({this.action, this.targetId = ''});

  /// The action to show; null for all of them.
  final String? action;

  /// The id of the thing acted on.
  final String targetId;

  AuditFilter copyWith({String? Function()? action, String? targetId}) {
    return AuditFilter(
      action: action != null ? action() : this.action,
      targetId: targetId ?? this.targetId,
    );
  }

  @override
  List<Object?> get props => [action, targetId];
}

/// The actions the audit log records, for the filter.
const auditActions = [
  'view_verification',
  'approve_verification',
  'reject_verification',
  'approve_topup',
  'reject_topup',
  'resolve_complaint',
  'suspend_user',
  'restore_user',
  'update_settings',
  'create_credit_pack',
  'update_credit_pack',
  'update_payment_account',
  'create_area',
  'update_area',
  'set_area_open',
];
