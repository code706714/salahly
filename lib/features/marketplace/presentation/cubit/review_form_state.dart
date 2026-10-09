part of 'review_form_cubit.dart';

final class ReviewFormState extends Equatable {
  const ReviewFormState({
    this.stars = 0,
    this.tags = const {},
    this.paidWith,
    this.comment = '',
  });

  /// 0 until the consumer picks a star.
  final int stars;
  final Set<ReviewTag> tags;
  final ConsumerPayment? paidWith;
  final String comment;

  /// The rating to send, once it has stars and how the job was paid.
  ReviewDraft? get draft {
    final paidWith = this.paidWith;
    if (stars == 0 || paidWith == null) return null;
    return ReviewDraft(
      stars: stars,
      tags: tags,
      comment: normalizeText(comment),
      paidWith: paidWith,
    );
  }

  ReviewFormState copyWith({
    int? stars,
    Set<ReviewTag>? tags,
    ConsumerPayment? paidWith,
    String? comment,
  }) {
    return ReviewFormState(
      stars: stars ?? this.stars,
      tags: tags ?? this.tags,
      paidWith: paidWith ?? this.paidWith,
      comment: comment ?? this.comment,
    );
  }

  @override
  List<Object?> get props => [stars, tags, paidWith, comment];
}
