import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

/// A consumer's request as a technician sees it: the area and the
/// consumer's first name, never the address or phone number.
final class IncomingRequest extends Equatable {
  const IncomingRequest({
    required this.id,
    required this.categoryId,
    required this.issue,
    required this.areaId,
    required this.distanceKm,
    required this.day,
    required this.window,
    required this.expiresAt,
    required this.createdAt,
    required this.consumerName,
    required this.consumerHonorific,
    required this.status,
    required this.sentTo,
    required this.offerCount,
    required this.dismissed,
    this.description,
    this.photoPaths = const [],
    this.myOffer,
  });

  final String id;
  final String categoryId;
  final RequestIssue issue;
  final String? description;

  /// Paths in the private request photos bucket.
  final List<String> photoPaths;
  final String areaId;

  /// From the technician's base to the request's area.
  final double distanceKm;

  /// The day asked for, as local midnight.
  final DateTime day;
  final RequestWindow window;

  /// The last moment an offer can be sent.
  final DateTime expiresAt;
  final DateTime createdAt;

  /// First name and initial: "نورهان م.".
  final String consumerName;

  /// Picks the copy's grammatical gender: "العميلة" or "العميل".
  final Honorific consumerHonorific;
  final RequestStatus status;

  /// How many technicians got it, and how many offers it has.
  final int sentTo;
  final int offerCount;

  /// The technician said it isn't for them.
  final bool dismissed;
  final MyOffer? myOffer;

  /// A request takes at most three offers.
  static const maxOffers = 3;

  /// Whether this technician can still send an offer.
  bool get acceptsOffers =>
      status == RequestStatus.open && myOffer == null && offerCount < maxOffers;

  @override
  List<Object?> get props => [
    id,
    categoryId,
    issue,
    description,
    photoPaths,
    areaId,
    distanceKm,
    day,
    window,
    expiresAt,
    createdAt,
    consumerName,
    consumerHonorific,
    status,
    sentTo,
    offerCount,
    dismissed,
    myOffer,
  ];
}

/// The offer this technician sent on a request.
final class MyOffer extends Equatable {
  const MyOffer({
    required this.id,
    required this.pricePiastres,
    required this.arriveAt,
    required this.status,
    this.serviceId,
    this.note,
  });

  final String id;
  final String? serviceId;
  final int pricePiastres;
  final DateTime arriveAt;
  final String? note;
  final OfferStatus status;

  @override
  List<Object?> get props => [
    id,
    serviceId,
    pricePiastres,
    arriveAt,
    note,
    status,
  ];
}

/// An offer ready to send.
final class OfferDraft extends Equatable {
  const OfferDraft({
    required this.pricePiastres,
    required this.arriveAt,
    this.serviceId,
    this.note,
  });

  /// The service chip the price came from, if any.
  final String? serviceId;
  final int pricePiastres;
  final DateTime arriveAt;
  final String? note;

  @override
  List<Object?> get props => [serviceId, pricePiastres, arriveAt, note];
}
