import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

/// Which complaints a list shows.
enum ComplaintFilter { open, resolved, all }

/// The customer or the technician a complaint is between.
final class ComplaintParty extends Equatable {
  const ComplaintParty({
    required this.id,
    required this.name,
    required this.phone,
    this.suspended = false,
  });

  final String id;
  final String name;

  /// In international form, so the team can call or message them.
  final String phone;
  final bool suspended;

  @override
  List<Object?> get props => [id, name, phone, suspended];
}

/// A customer's complaint about a technician.
final class AdminComplaint extends Equatable {
  const AdminComplaint({
    required this.id,
    required this.requestId,
    required this.requestCode,
    required this.reason,
    required this.createdAt,
    required this.issue,
    required this.areaId,
    required this.consumer,
    required this.technician,
    this.details,
    this.photoPath,
    this.resolvedAt,
    this.resolutionNote,
  });

  final String id;
  final String requestId;
  final String requestCode;
  final ComplaintReason reason;

  /// What the customer wrote. Untrusted text: show it as plain text.
  final String? details;

  /// A photo in the `request-photos` bucket.
  final String? photoPath;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final RequestIssue issue;
  final String areaId;
  final ComplaintParty consumer;
  final ComplaintParty technician;

  bool get isResolved => resolvedAt != null;

  @override
  List<Object?> get props => [
    id,
    requestId,
    requestCode,
    reason,
    details,
    photoPath,
    createdAt,
    resolvedAt,
    resolutionNote,
    issue,
    areaId,
    consumer,
    technician,
  ];
}
