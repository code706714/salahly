import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';

part 'review_form_state.dart';

/// The rating the consumer is writing for a finished job. Sending it goes
/// through the request's cubit.
class ReviewFormCubit extends Cubit<ReviewFormState> {
  ReviewFormCubit() : super(const ReviewFormState());

  /// 1 to 5.
  void rate(int stars) {
    assert(stars >= 1 && stars <= 5, 'Ratings are 1 to 5 stars');
    emit(state.copyWith(stars: stars));
  }

  void toggleTag(ReviewTag tag) {
    final tags = {...state.tags};
    if (!tags.remove(tag)) tags.add(tag);
    emit(state.copyWith(tags: tags));
  }

  void payWith(ConsumerPayment payment) =>
      emit(state.copyWith(paidWith: payment));

  void writeComment(String comment) => emit(state.copyWith(comment: comment));
}
