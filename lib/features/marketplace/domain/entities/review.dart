import 'package:equatable/equatable.dart';

/// The chips a consumer can add to a rating.
enum ReviewTag { onTime, cleanWork, fairPrice, explained, respectful }

/// How the consumer says they paid the technician.
enum ConsumerPayment { cash, instapay, notYet }

/// A rating ready to send.
final class ReviewDraft extends Equatable {
  const ReviewDraft({
    required this.stars,
    required this.paidWith,
    this.tags = const {},
    this.comment,
  });

  /// 1 to 5.
  final int stars;
  final Set<ReviewTag> tags;
  final String? comment;
  final ConsumerPayment paidWith;

  @override
  List<Object?> get props => [stars, tags, comment, paidWith];
}
