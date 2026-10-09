import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

/// Where a request stands, from the platform's side.
enum AdminRequestStatus {
  /// Open and nobody has offered.
  noOffers,

  /// Offers came in and the customer has not picked one.
  awaitingChoice,

  /// A technician was picked and the job is not finished.
  inProgress,
  done,
  cancelled,
  expired,
}

/// A customer's request, as a row of the requests list.
///
/// Names are a first name and an initial; no phone or address comes with it.
final class AdminRequest extends Equatable {
  const AdminRequest({
    required this.id,
    required this.code,
    required this.createdAt,
    required this.issue,
    required this.areaId,
    required this.areaName,
    required this.consumerName,
    required this.offerCount,
    required this.status,
    required this.hasOpenComplaint,
    required this.hasComplaint,
    this.technicianName,
    this.stars,
  });

  final String id;

  /// The short code the team and the customer quote, like "R-1A2B3C".
  final String code;
  final DateTime createdAt;
  final RequestIssue issue;
  final String areaId;
  final String areaName;
  final String consumerName;

  /// The technician the customer picked, if they did.
  final String? technicianName;
  final int offerCount;
  final AdminRequestStatus status;

  /// The customer's rating of the finished job.
  final int? stars;
  final bool hasOpenComplaint;
  final bool hasComplaint;

  @override
  List<Object?> get props => [
    id,
    code,
    createdAt,
    issue,
    areaId,
    areaName,
    consumerName,
    technicianName,
    offerCount,
    status,
    stars,
    hasOpenComplaint,
    hasComplaint,
  ];
}

/// What the requests list is narrowed to.
final class RequestFilter extends Equatable {
  const RequestFilter({
    this.search = '',
    this.areaId,
    this.status,
    this.days = 7,
  });

  /// A request code, or part of a name or phone.
  final String search;
  final String? areaId;
  final AdminRequestStatus? status;

  /// Only requests from the last [days] days; null for all of them.
  final int? days;

  RequestFilter copyWith({
    String? search,
    String? Function()? areaId,
    AdminRequestStatus? Function()? status,
    int? Function()? days,
  }) {
    return RequestFilter(
      search: search ?? this.search,
      areaId: areaId != null ? areaId() : this.areaId,
      status: status != null ? status() : this.status,
      days: days != null ? days() : this.days,
    );
  }

  @override
  List<Object?> get props => [search, areaId, status, days];
}
