import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';

/// What happened, which also says whose side of the app it is for.
enum NotificationKind {
  // The consumer's.
  offerReceived,
  jobConfirmed,
  jobStarted,
  jobFinished,
  priceChange,
  requestCancelledByTechnician,
  requestExpired,

  // The technician's.
  newRequest,
  offerPicked,
  offerNotPicked,
  requestCancelledByConsumer,
  verificationApproved,
  verificationRejected,

  // Both.
  topupApproved,
  topupRejected;

  /// Whether the notification is about a transfer.
  bool get isAboutTopup => this == topupApproved || this == topupRejected;

  /// Whether the notification is about the technician's documents.
  bool get isAboutVerification =>
      this == verificationApproved || this == verificationRejected;
}

/// One thing that happened, with what its text needs. Everything but the
/// kind may be missing: the request, offer or transfer it points at can
/// be gone, and the text then says only what happened.
final class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.readAt,
    this.requestId,
    this.topupId,
    this.categoryId,
    this.issue,
    this.areaId,
    this.day,
    this.window,
    this.pricePiastres,
    this.arriveAt,
    this.technicianName,
    this.consumerName,
    this.consumerHonorific,
    this.distanceKm,
    this.topupUses,
  });

  final String id;
  final NotificationKind kind;
  final DateTime createdAt;

  /// When it was read; null while it is new.
  final DateTime? readAt;
  final String? requestId;
  final String? topupId;
  final String? categoryId;
  final RequestIssue? issue;
  final String? areaId;

  /// The day and part of the day the request asked for.
  final DateTime? day;
  final RequestWindow? window;

  /// The price offered, and when the technician said they would come.
  final int? pricePiastres;
  final DateTime? arriveAt;

  /// The technician, as a consumer sees them.
  final String? technicianName;

  /// The consumer's first name and initial, as a technician sees them.
  final String? consumerName;
  final Honorific? consumerHonorific;

  /// How far the request is from the technician.
  final double? distanceKm;

  /// The uses a transfer bought.
  final int? topupUses;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) => isRead
      ? this
      : AppNotification(
          id: id,
          kind: kind,
          createdAt: createdAt,
          readAt: at,
          requestId: requestId,
          topupId: topupId,
          categoryId: categoryId,
          issue: issue,
          areaId: areaId,
          day: day,
          window: window,
          pricePiastres: pricePiastres,
          arriveAt: arriveAt,
          technicianName: technicianName,
          consumerName: consumerName,
          consumerHonorific: consumerHonorific,
          distanceKm: distanceKm,
          topupUses: topupUses,
        );

  @override
  List<Object?> get props => [
    id,
    kind,
    createdAt,
    readAt,
    requestId,
    topupId,
    categoryId,
    issue,
    areaId,
    day,
    window,
    pricePiastres,
    arriveAt,
    technicianName,
    consumerName,
    consumerHonorific,
    distanceKm,
    topupUses,
  ];
}
