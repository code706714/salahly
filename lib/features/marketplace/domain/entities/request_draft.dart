import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';

/// A request ready to send.
final class RequestDraft extends Equatable {
  const RequestDraft({
    required this.categoryId,
    required this.issue,
    required this.addressId,
    required this.day,
    required this.window,
    this.description,
    this.photoPaths = const [],
    this.technicianId,
    this.warrantyOf,
    this.urgent = false,
  });

  final String categoryId;
  final RequestIssue issue;
  final String? description;

  /// Storage paths of photos already uploaded with
  /// `ConsumerRequestsRepository.uploadPhoto`, at most four.
  final List<String> photoPaths;
  final String addressId;

  /// The day, as local midnight.
  final DateTime day;
  final RequestWindow window;

  /// Someone the consumer hired before and asks again first.
  final String? technicianId;

  /// The request whose job this is a free warranty visit for, if it is one.
  final String? warrantyOf;

  /// Sent to the technicians who are free now, for today, with the urgent
  /// fee on top.
  final bool urgent;

  @override
  List<Object?> get props => [
    categoryId,
    issue,
    description,
    photoPaths,
    addressId,
    day,
    window,
    technicianId,
    warrantyOf,
    urgent,
  ];
}

/// The urgent fee and how many technicians are free now in an area.
final class UrgentInfo extends Equatable {
  const UrgentInfo({required this.feePiastres, required this.availableNow});

  final int feePiastres;
  final int availableNow;

  @override
  List<Object?> get props => [feePiastres, availableNow];
}

/// What a job like the one asked for usually costs.
final class PriceGuide extends Equatable {
  const PriceGuide({
    required this.lowPiastres,
    required this.highPiastres,
    required this.fromOffers,
  });

  final int lowPiastres;
  final int highPiastres;

  /// Whether the range comes from offers consumers accepted, rather than
  /// from the technicians' suggested prices.
  final bool fromOffers;

  @override
  List<Object?> get props => [lowPiastres, highPiastres, fromOffers];
}

/// A request the server accepted, and how many technicians it reached.
final class SentRequest extends Equatable {
  const SentRequest({required this.id, required this.sentTo});

  final String id;
  final int sentTo;

  @override
  List<Object?> get props => [id, sentTo];
}
