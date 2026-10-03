import 'package:equatable/equatable.dart';

/// What went wrong, from the complaint screen.
enum ComplaintReason { noShowOrLate, priceRaised, poorWork, badConduct, other }

/// A complaint ready to send.
final class ComplaintDraft extends Equatable {
  const ComplaintDraft({required this.reason, this.details, this.photoPath});

  final ComplaintReason reason;
  final String? details;

  /// A photo or screenshot already uploaded with
  /// `ConsumerRequestsRepository.uploadPhoto`.
  final String? photoPath;

  @override
  List<Object?> get props => [reason, details, photoPath];
}
