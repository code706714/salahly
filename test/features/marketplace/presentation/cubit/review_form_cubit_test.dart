import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/presentation/cubit/review_form_cubit.dart';

void main() {
  test('starts empty, with nothing to send', () {
    final cubit = ReviewFormCubit();

    expect(cubit.state, const ReviewFormState());
    expect(cubit.state.draft, isNull);
  });

  blocTest<ReviewFormCubit, ReviewFormState>(
    'rates and changes the rating',
    build: ReviewFormCubit.new,
    act: (cubit) => cubit
      ..rate(3)
      ..rate(5),
    expect: () => const [ReviewFormState(stars: 3), ReviewFormState(stars: 5)],
  );

  blocTest<ReviewFormCubit, ReviewFormState>(
    'toggles chips on and off',
    build: ReviewFormCubit.new,
    act: (cubit) => cubit
      ..toggleTag(ReviewTag.onTime)
      ..toggleTag(ReviewTag.fairPrice)
      ..toggleTag(ReviewTag.onTime),
    expect: () => const [
      ReviewFormState(tags: {ReviewTag.onTime}),
      ReviewFormState(tags: {ReviewTag.onTime, ReviewTag.fairPrice}),
      ReviewFormState(tags: {ReviewTag.fairPrice}),
    ],
  );

  blocTest<ReviewFormCubit, ReviewFormState>(
    'keeps how it was paid and the comment',
    build: ReviewFormCubit.new,
    act: (cubit) => cubit
      ..payWith(ConsumerPayment.notYet)
      ..writeComment('تمام'),
    expect: () => const [
      ReviewFormState(paidWith: ConsumerPayment.notYet),
      ReviewFormState(paidWith: ConsumerPayment.notYet, comment: 'تمام'),
    ],
  );

  group('draft', () {
    test('needs both the stars and the payment', () {
      expect(const ReviewFormState(stars: 4).draft, isNull);
      expect(
        const ReviewFormState(paidWith: ConsumerPayment.cash).draft,
        isNull,
      );
    });

    test('carries everything, with the comment tidied', () {
      const state = ReviewFormState(
        stars: 4,
        tags: {ReviewTag.explained},
        paidWith: ConsumerPayment.instapay,
        comment: '  كويس   جداً  ',
      );

      expect(
        state.draft,
        const ReviewDraft(
          stars: 4,
          tags: {ReviewTag.explained},
          paidWith: ConsumerPayment.instapay,
          comment: 'كويس جداً',
        ),
      );
    });

    test('drops a blank comment', () {
      const state = ReviewFormState(
        stars: 1,
        paidWith: ConsumerPayment.cash,
        comment: '   ',
      );

      expect(state.draft!.comment, isNull);
    });
  });
}
