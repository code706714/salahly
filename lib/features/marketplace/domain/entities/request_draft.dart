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
  ];
}

/// A request the server accepted, and how many technicians it reached.
final class SentRequest extends Equatable {
  const SentRequest({required this.id, required this.sentTo});

  final String id;
  final int sentTo;

  @override
  List<Object?> get props => [id, sentTo];
}
