import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

/// Where a request stands on the server.
enum RequestStatus {
  /// Waiting for offers, or for the consumer to pick one.
  open,

  /// The consumer picked a technician; the job decides the rest.
  assigned,
  cancelled,

  /// Its time passed without a pick.
  expired,
}

/// Where a request stands for the consumer, combining the request and the
/// technician's job: what "طلباتي" and the tracking screen show.
enum RequestStage {
  waitingForOffers,
  choosingOffer,

  /// Picked, waiting for the technician to confirm the time.
  chosen,
  confirmed,
  started,

  /// Finished (paid or not).
  done,
  cancelled,
  expired;

  /// Still in progress, as opposed to the history.
  bool get isActive => switch (this) {
    waitingForOffers || choosingOffer || chosen || confirmed || started => true,
    done || cancelled || expired => false,
  };
}

RequestStage _stageOf(RequestStatus status, int offerCount, JobStatus? job) =>
    switch (status) {
      RequestStatus.open when offerCount == 0 => RequestStage.waitingForOffers,
      RequestStatus.open => RequestStage.choosingOffer,
      RequestStatus.cancelled => RequestStage.cancelled,
      RequestStatus.expired => RequestStage.expired,
      RequestStatus.assigned => switch (job) {
        JobStatus.confirmed => RequestStage.confirmed,
        JobStatus.started => RequestStage.started,
        JobStatus.finished || JobStatus.paid => RequestStage.done,
        JobStatus.cancelled => RequestStage.cancelled,
        JobStatus.unconfirmed || null => RequestStage.chosen,
      },
    };

/// A request in the consumer's list.
final class RequestSummary extends Equatable {
  const RequestSummary({
    required this.id,
    required this.categoryId,
    required this.issue,
    required this.status,
    required this.day,
    required this.window,
    required this.createdAt,
    required this.offerCount,
    this.description,
    this.cancelledBy,
    this.technicianId,
    this.technicianName,
    this.pricePiastres,
    this.jobStatus,
    this.scheduledAt,
    this.reviewStars,
  });

  final String id;
  final String categoryId;
  final RequestIssue issue;
  final String? description;
  final RequestStatus status;
  final UserRole? cancelledBy;

  /// The day asked for, as local midnight.
  final DateTime day;
  final RequestWindow window;
  final DateTime createdAt;
  final int offerCount;

  /// The picked technician, once there is one.
  final String? technicianId;
  final String? technicianName;

  /// The picked offer's price.
  final int? pricePiastres;
  final JobStatus? jobStatus;

  /// When the picked technician is coming.
  final DateTime? scheduledAt;

  /// The consumer's rating, once given.
  final int? reviewStars;

  RequestStage get stage => _stageOf(status, offerCount, jobStatus);

  @override
  List<Object?> get props => [
    id,
    categoryId,
    issue,
    description,
    status,
    cancelledBy,
    day,
    window,
    createdAt,
    offerCount,
    technicianId,
    technicianName,
    pricePiastres,
    jobStatus,
    scheduledAt,
    reviewStars,
  ];
}

/// Everything the consumer's request screens show about one request.
final class RequestDetails extends Equatable {
  const RequestDetails({
    required this.id,
    required this.categoryId,
    required this.issue,
    required this.areaId,
    required this.addressLabel,
    required this.addressDetails,
    required this.day,
    required this.window,
    required this.expiresAt,
    required this.status,
    required this.widened,
    required this.createdAt,
    required this.sentTo,
    required this.seenBy,
    required this.offers,
    required this.hasOpenComplaint,
    this.description,
    this.photoPaths = const [],
    this.cancelledBy,
    this.cancelledAt,
    this.chosenAt,
    this.chosenOfferId,
    this.technicianPhone,
    this.job,
    this.review,
  });

  final String id;
  final String categoryId;
  final RequestIssue issue;
  final String? description;

  /// Paths in the private request photos bucket.
  final List<String> photoPaths;
  final String areaId;
  final String addressLabel;
  final String addressDetails;

  /// The day asked for, as local midnight.
  final DateTime day;
  final RequestWindow window;

  /// When the request stops taking offers and picks.
  final DateTime expiresAt;
  final RequestStatus status;
  final UserRole? cancelledBy;
  final DateTime? cancelledAt;

  /// It was sent to technicians further away after two hours without an
  /// offer.
  final bool widened;
  final DateTime createdAt;
  final DateTime? chosenAt;

  /// How many technicians got it, and how many opened it.
  final int sentTo;
  final int seenBy;

  /// Oldest first.
  final List<RequestOffer> offers;
  final String? chosenOfferId;

  /// The picked technician's number, while the request is assigned.
  final String? technicianPhone;
  final RequestJob? job;
  final SubmittedReview? review;
  final bool hasOpenComplaint;

  RequestOffer? get chosenOffer =>
      offers.where((offer) => offer.id == chosenOfferId).firstOrNull;

  RequestStage get stage => _stageOf(status, offers.length, job?.status);

  /// A price change the technician sent and the consumer hasn't answered.
  bool get hasPendingPriceChange => job?.quoteStatus == QuoteStatus.sent;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    issue,
    description,
    photoPaths,
    areaId,
    addressLabel,
    addressDetails,
    day,
    window,
    expiresAt,
    status,
    cancelledBy,
    cancelledAt,
    widened,
    createdAt,
    chosenAt,
    sentTo,
    seenBy,
    offers,
    chosenOfferId,
    technicianPhone,
    job,
    review,
    hasOpenComplaint,
  ];
}

/// Whether an offer is still in the running.
enum OfferStatus { sent, accepted, notChosen }

/// A technician's offer on a consumer's request.
final class RequestOffer extends Equatable {
  const RequestOffer({
    required this.id,
    required this.pricePiastres,
    required this.arriveAt,
    required this.status,
    required this.createdAt,
    required this.technician,
    this.note,
    this.distanceKm,
  });

  final String id;

  /// The starting price.
  final int pricePiastres;
  final DateTime arriveAt;
  final String? note;
  final OfferStatus status;

  /// From the technician's base to the request's area.
  final double? distanceKm;
  final DateTime createdAt;
  final TechnicianCard technician;

  @override
  List<Object?> get props => [
    id,
    pricePiastres,
    arriveAt,
    note,
    status,
    distanceKm,
    createdAt,
    technician,
  ];
}

/// The picked technician's job, as the consumer follows it.
final class RequestJob extends Equatable {
  const RequestJob({
    required this.status,
    required this.quoteStatus,
    required this.items,
    required this.totalPiastres,
    this.scheduledAt,
    this.confirmedAt,
    this.startedAt,
    this.finishedAt,
    this.paidAt,
    this.cancelledAt,
    this.quoteSentAt,
    this.invoiceNumber,
  });

  final JobStatus status;
  final DateTime? scheduledAt;
  final DateTime? confirmedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final QuoteStatus quoteStatus;

  /// Names the price change being answered.
  final DateTime? quoteSentAt;
  final int? invoiceNumber;
  final List<PriceLine> items;
  final int totalPiastres;

  @override
  List<Object?> get props => [
    status,
    scheduledAt,
    confirmedAt,
    startedAt,
    finishedAt,
    paidAt,
    cancelledAt,
    quoteStatus,
    quoteSentAt,
    invoiceNumber,
    items,
    totalPiastres,
  ];
}

/// A line of the job's price.
final class PriceLine extends Equatable {
  const PriceLine({
    required this.title,
    required this.unitPricePiastres,
    required this.quantity,
    required this.addedLater,
  });

  final String title;
  final int unitPricePiastres;
  final int quantity;

  /// Added or changed after the consumer picked the offer: "(جديد)".
  final bool addedLater;

  int get totalPiastres => unitPricePiastres * quantity;

  @override
  List<Object?> get props => [title, unitPricePiastres, quantity, addedLater];
}

/// The consumer's own rating of the job.
final class SubmittedReview extends Equatable {
  const SubmittedReview({
    required this.stars,
    required this.paidWith,
    required this.createdAt,
    this.tags = const {},
    this.comment,
  });

  final int stars;
  final Set<ReviewTag> tags;
  final String? comment;
  final ConsumerPayment paidWith;
  final DateTime createdAt;

  @override
  List<Object?> get props => [stars, tags, comment, paidWith, createdAt];
}
