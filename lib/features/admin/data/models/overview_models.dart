import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';

/// Maps what `admin_overview` and `admin_list_areas` return.
abstract final class OverviewModels {
  static AdminOverview overview(Map<String, dynamic> json) {
    final requests = json['requests'] as Map<String, dynamic>;
    final funnel = json['funnel'] as Map<String, dynamic>;
    final rating = json['rating'] as Map<String, dynamic>;
    final unanswered = json['requests_without_offers'] as Map<String, dynamic>;
    final verifications = json['pending_verifications'] as Map<String, dynamic>;
    final complaints = json['open_complaints'] as Map<String, dynamic>;
    final topups = json['pending_topups'] as Map<String, dynamic>;
    return AdminOverview(
      period: enumFromWire(OverviewPeriod.values, json['period']),
      verifiedTechnicians: intOf(json['verified_technicians']),
      verifiedTechnicianTarget: intOf(json['verified_technician_target']),
      requests: RequestVolume(
        count: intOf(requests['count']),
        previousCount: intOf(requests['previous_count']),
      ),
      funnel: RequestFunnel(
        sent: intOf(funnel['sent']),
        withOffer: intOf(funnel['with_offer']),
        chosen: intOf(funnel['chosen']),
        finished: intOf(funnel['finished']),
      ),
      rating: RatingSummary(
        average: optionalDoubleOf(rating['average']),
        count: intOf(rating['count']),
      ),
      unanswered: UnansweredRequests(
        count: intOf(unanswered['count']),
        olderThanHours: intOf(unanswered['older_than_hours']),
        topAreas: [
          for (final area in listFromWire(unanswered['top_areas']))
            AreaDemand(
              areaId: area['area_id'] as String,
              name: area['name_ar'] as String,
              count: intOf(area['count']),
            ),
        ],
      ),
      pendingVerifications: PendingVerifications(
        count: intOf(verifications['count']),
        oldestAt: optionalTimeFromWire(verifications['oldest_at']),
      ),
      openComplaints: OpenComplaints(
        count: intOf(complaints['count']),
        byReason: _complaintCounts(complaints['by_reason']),
      ),
      pendingTopups: PendingTopups(
        count: intOf(topups['count']),
        technicians: intOf(topups['technicians']),
        consumers: intOf(topups['consumers']),
      ),
      lowRated: [
        for (final technician in listFromWire(json['low_rated_technicians']))
          LowRatedTechnician(
            id: technician['id'] as String,
            name: technician['name'] as String,
            rating: (technician['rating'] as num).toDouble(),
            reviewCount: intOf(technician['review_count']),
          ),
      ],
    );
  }

  static AreaCoverageReport areas(Map<String, dynamic> json) =>
      AreaCoverageReport(
        adsMinTechnicians: intOf(json['ads_min_technicians']),
        areas: [
          for (final area in listFromWire(json['items']))
            AreaCoverage(
              id: area['id'] as String,
              name: area['name_ar'] as String,
              city: area['city_ar'] as String,
              isOpen: area['is_open'] as bool,
              verifiedTechnicians: intOf(area['verified_technicians']),
              requests: intOf(area['requests']),
              gotOfferPercent: optionalIntOf(area['got_offer_percent']),
              adsActive: area['ads_active'] as bool,
            ),
        ],
      );

  /// The counts by reason, skipping a reason this version doesn't know.
  static Map<ComplaintReason, int> _complaintCounts(Object? wire) {
    final counts = wire! as Map<String, dynamic>;
    return {
      for (final reason in ComplaintReason.values)
        if (counts[toWire(reason)] case final count?) reason: intOf(count),
    };
  }
}
