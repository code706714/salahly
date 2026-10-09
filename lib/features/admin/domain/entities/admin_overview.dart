import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';

/// The span the overview's numbers cover.
enum OverviewPeriod { today, week, month }

/// How many requests came in over the period, and over the one before it.
final class RequestVolume extends Equatable {
  const RequestVolume({required this.count, required this.previousCount});

  final int count;
  final int previousCount;

  /// How many more (or fewer, when negative) than the period before.
  int get change => count - previousCount;

  @override
  List<Object?> get props => [count, previousCount];
}

/// How far requests got over the period.
final class RequestFunnel extends Equatable {
  const RequestFunnel({
    required this.sent,
    required this.withOffer,
    required this.chosen,
    required this.finished,
  });

  final int sent;
  final int withOffer;
  final int chosen;
  final int finished;

  @override
  List<Object?> get props => [sent, withOffer, chosen, finished];
}

/// The average of the reviews written over the period.
final class RatingSummary extends Equatable {
  const RatingSummary({required this.average, required this.count});

  /// Null when nobody reviewed anyone.
  final double? average;
  final int count;

  @override
  List<Object?> get props => [average, count];
}

/// A count of requests in one area.
final class AreaDemand extends Equatable {
  const AreaDemand({
    required this.areaId,
    required this.name,
    required this.count,
  });

  final String areaId;
  final String name;
  final int count;

  @override
  List<Object?> get props => [areaId, name, count];
}

/// Open requests nobody has offered on for a while.
final class UnansweredRequests extends Equatable {
  const UnansweredRequests({
    required this.count,
    required this.olderThanHours,
    required this.topAreas,
  });

  final int count;
  final int olderThanHours;

  /// The areas with the most of them, most first.
  final List<AreaDemand> topAreas;

  @override
  List<Object?> get props => [count, olderThanHours, topAreas];
}

/// Technicians waiting for their ID check.
final class PendingVerifications extends Equatable {
  const PendingVerifications({required this.count, this.oldestAt});

  final int count;

  /// When the longest-waiting one was sent; null when none is waiting.
  final DateTime? oldestAt;

  @override
  List<Object?> get props => [count, oldestAt];
}

/// Complaints nobody has closed yet.
final class OpenComplaints extends Equatable {
  const OpenComplaints({required this.count, required this.byReason});

  final int count;
  final Map<ComplaintReason, int> byReason;

  @override
  List<Object?> get props => [count, byReason];
}

/// Transfers waiting to be checked, by who sent them.
final class PendingTopups extends Equatable {
  const PendingTopups({
    required this.count,
    required this.technicians,
    required this.consumers,
  });

  final int count;
  final int technicians;
  final int consumers;

  @override
  List<Object?> get props => [count, technicians, consumers];
}

/// A technician whose reviews average below the platform's bar.
final class LowRatedTechnician extends Equatable {
  const LowRatedTechnician({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
  });

  final String id;
  final String name;
  final double rating;
  final int reviewCount;

  @override
  List<Object?> get props => [id, name, rating, reviewCount];
}

/// The numbers on the dashboard's first page.
final class AdminOverview extends Equatable {
  const AdminOverview({
    required this.period,
    required this.verifiedTechnicians,
    required this.verifiedTechnicianTarget,
    required this.requests,
    required this.funnel,
    required this.rating,
    required this.unanswered,
    required this.pendingVerifications,
    required this.openComplaints,
    required this.pendingTopups,
    required this.lowRated,
  });

  final OverviewPeriod period;
  final int verifiedTechnicians;
  final int verifiedTechnicianTarget;
  final RequestVolume requests;
  final RequestFunnel funnel;
  final RatingSummary rating;
  final UnansweredRequests unanswered;
  final PendingVerifications pendingVerifications;
  final OpenComplaints openComplaints;
  final PendingTopups pendingTopups;
  final List<LowRatedTechnician> lowRated;

  @override
  List<Object?> get props => [
    period,
    verifiedTechnicians,
    verifiedTechnicianTarget,
    requests,
    funnel,
    rating,
    unanswered,
    pendingVerifications,
    openComplaints,
    pendingTopups,
    lowRated,
  ];
}
