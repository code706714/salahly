import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

/// Maps the marketplace tables and functions' JSON to domain entities.
abstract final class MarketplaceModels {
  static const addressSelect = 'id, label, area_id, details';

  static ConsumerAddress address(Map<String, dynamic> json) => ConsumerAddress(
    id: json['id'] as String,
    label: json['label'] as String,
    areaId: json['area_id'] as String,
    details: json['details'] as String,
  );

  static RequestSummary summary(Map<String, dynamic> json) {
    final technician = json['technician'] as Map<String, dynamic>?;
    return RequestSummary(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      issue: enumFromWire(RequestIssue.values, json['issue']),
      description: json['description'] as String?,
      status: enumFromWire(RequestStatus.values, json['status']),
      cancelledBy: _role(json['cancelled_by']),
      day: dateFromWire(json['preferred_on']),
      window: enumFromWire(RequestWindow.values, json['time_window']),
      createdAt: timeFromWire(json['created_at']),
      offerCount: json['offer_count'] as int,
      technicianId: technician?['id'] as String?,
      technicianName: technician?['name'] as String?,
      pricePiastres: json['price_piastres'] as int?,
      jobStatus: _jobStatus(json['job_status']),
      scheduledAt: optionalTimeFromWire(json['scheduled_at']),
      reviewStars: json['review_stars'] as int?,
    );
  }

  static JobRequestLink jobRequestLink(Map<String, dynamic> json) =>
      JobRequestLink(
        requestId: json['request_id'] as String,
        arrivingSentAt: optionalTimeFromWire(json['arriving_sent_at']),
      );

  static RequestDetails details(Map<String, dynamic> json) {
    final job = json['job'] as Map<String, dynamic>?;
    final review = json['review'] as Map<String, dynamic>?;
    return RequestDetails(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      issue: enumFromWire(RequestIssue.values, json['issue']),
      description: json['description'] as String?,
      photoPaths: _strings(json['photo_paths']),
      areaId: json['area_id'] as String,
      addressLabel: json['address_label'] as String,
      addressDetails: json['address_details'] as String,
      day: dateFromWire(json['preferred_on']),
      window: enumFromWire(RequestWindow.values, json['time_window']),
      expiresAt: timeFromWire(json['expires_at']),
      status: enumFromWire(RequestStatus.values, json['status']),
      cancelledBy: _role(json['cancelled_by']),
      cancelledAt: optionalTimeFromWire(json['cancelled_at']),
      widened: json['widened'] as bool,
      createdAt: timeFromWire(json['created_at']),
      chosenAt: optionalTimeFromWire(json['chosen_at']),
      sentTo: json['sent_to'] as int,
      seenBy: json['seen_by'] as int,
      offers: listFromWire(json['offers']).map(_offer).toList(),
      chosenOfferId: json['chosen_offer_id'] as String?,
      technicianPhone: json['technician_phone'] as String?,
      job: job == null ? null : _job(job),
      review: review == null ? null : _review(review),
      hasOpenComplaint: json['open_complaint'] as bool,
      technicianArrivingAt: optionalTimeFromWire(
        json['technician_arriving_at'],
      ),
    );
  }

  static TechnicianPublicProfile technicianProfile(Map<String, dynamic> json) =>
      TechnicianPublicProfile(
        card: technicianCard(json),
        onTimePercent: (json['on_time_percent'] as num?)?.round(),
        areaIds: _strings(json['area_ids']),
        services: [
          for (final service in listFromWire(json['services']))
            ServicePrice(
              serviceId: service['service_id'] as String,
              startingPricePiastres: service['starting_price_piastres'] as int,
            ),
        ],
        reviews: [
          for (final review in listFromWire(json['reviews']))
            PublicReview(
              author: review['author'] as String,
              stars: review['stars'] as int,
              comment: review['comment'] as String?,
              tags: enumSetFromWire(ReviewTag.values, review['tags']),
              issue: enumFromWire(RequestIssue.values, review['issue']),
              createdAt: timeFromWire(review['created_at']),
            ),
        ],
      );

  static TechnicianCard technicianCard(Map<String, dynamic> json) =>
      TechnicianCard(
        id: json['id'] as String,
        name: json['name'] as String,
        shopName: json['shop_name'] as String?,
        avatarPath: json['avatar_path'] as String,
        yearsExperience: json['years_experience'] as int,
        verified: json['verified'] as bool,
        rating: (json['rating'] as num?)?.toDouble(),
        reviewCount: json['review_count'] as int,
        jobsDone: json['jobs_done'] as int,
      );

  static IncomingRequest incoming(Map<String, dynamic> json) {
    final offer = json['my_offer'] as Map<String, dynamic>?;
    return IncomingRequest(
      id: json['id'] as String,
      categoryId: json['category_id'] as String,
      issue: enumFromWire(RequestIssue.values, json['issue']),
      description: json['description'] as String?,
      photoPaths: _strings(json['photo_paths']),
      areaId: json['area_id'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      day: dateFromWire(json['preferred_on']),
      window: enumFromWire(RequestWindow.values, json['time_window']),
      expiresAt: timeFromWire(json['expires_at']),
      createdAt: timeFromWire(json['created_at']),
      consumerName: json['consumer_name'] as String,
      consumerHonorific: enumFromWire(
        Honorific.values,
        json['consumer_honorific'],
      ),
      status: enumFromWire(RequestStatus.values, json['status']),
      sentTo: json['sent_to'] as int,
      offerCount: json['offer_count'] as int,
      dismissed: json['dismissed'] as bool,
      myOffer: offer == null
          ? null
          : MyOffer(
              id: offer['id'] as String,
              serviceId: offer['service_id'] as String?,
              pricePiastres: offer['price_piastres'] as int,
              arriveAt: timeFromWire(offer['arrive_at']),
              note: offer['note'] as String?,
              status: enumFromWire(OfferStatus.values, offer['status']),
            ),
    );
  }

  static RequestOffer _offer(Map<String, dynamic> json) => RequestOffer(
    id: json['id'] as String,
    pricePiastres: json['price_piastres'] as int,
    arriveAt: timeFromWire(json['arrive_at']),
    note: json['note'] as String?,
    status: enumFromWire(OfferStatus.values, json['status']),
    distanceKm: (json['distance_km'] as num?)?.toDouble(),
    createdAt: timeFromWire(json['created_at']),
    technician: technicianCard(json['technician'] as Map<String, dynamic>),
  );

  static RequestJob _job(Map<String, dynamic> json) => RequestJob(
    status: enumFromWire(JobStatus.values, json['status']),
    scheduledAt: optionalTimeFromWire(json['scheduled_at']),
    confirmedAt: optionalTimeFromWire(json['confirmed_at']),
    startedAt: optionalTimeFromWire(json['started_at']),
    finishedAt: optionalTimeFromWire(json['finished_at']),
    paidAt: optionalTimeFromWire(json['paid_at']),
    cancelledAt: optionalTimeFromWire(json['cancelled_at']),
    quoteStatus: enumFromWire(QuoteStatus.values, json['quote_status']),
    quoteSentAt: optionalTimeFromWire(json['quote_sent_at']),
    invoiceNumber: json['invoice_number'] as int?,
    items: [
      for (final item in listFromWire(json['items']))
        PriceLine(
          title: item['title'] as String,
          unitPricePiastres: item['unit_price_piastres'] as int,
          quantity: item['quantity'] as int,
          addedLater: item['added_later'] as bool,
        ),
    ],
    totalPiastres: json['total_piastres'] as int,
  );

  static SubmittedReview _review(Map<String, dynamic> json) => SubmittedReview(
    stars: json['stars'] as int,
    tags: enumSetFromWire(ReviewTag.values, json['tags']),
    comment: json['comment'] as String?,
    paidWith: enumFromWire(ConsumerPayment.values, json['paid_with']),
    createdAt: timeFromWire(json['created_at']),
  );

  static UserRole? _role(Object? wire) =>
      wire == null ? null : enumFromWire(UserRole.values, wire);

  static JobStatus? _jobStatus(Object? wire) =>
      wire == null ? null : enumFromWire(JobStatus.values, wire);

  static List<String> _strings(Object? wire) => [
    for (final value in (wire as List<Object?>? ?? const [])) value! as String,
  ];
}
