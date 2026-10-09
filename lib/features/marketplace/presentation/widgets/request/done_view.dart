import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/review_form_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/complaint_link.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/request_unavailable_view.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The finished work: the invoice, how it was paid and the rating.
class DoneView extends StatelessWidget {
  const DoneView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final offer = details.chosenOffer;
    if (offer == null) return const RequestUnavailableView(missing: false);
    final technician = offer.technician.name;
    final review = details.review;
    final invoice = _Invoice(details: details, technician: technician);
    if (review != null) {
      return _Reviewed(
        details: details,
        technician: technician,
        review: review,
        invoice: invoice,
      );
    }
    return BlocProvider(
      create: (_) => ReviewFormCubit(),
      child: _ReviewForm(technician: technician, invoice: invoice),
    );
  }
}

/// The technician's invoice: its lines, the total, and what was added
/// after the pick.
class _Invoice extends StatelessWidget {
  const _Invoice({required this.details, required this.technician});

  final RequestDetails details;
  final String technician;

  String? _note(AppLocalizations l10n, String honorific) {
    final added = details.addedLines;
    if (added.isEmpty) return null;
    final items = added.map((line) => line.title).join(' و');
    return switch (details.priceChangeAnswer) {
      QuoteStatus.accepted => l10n.doneAddedApproved(
        honorific,
        added.length,
        items,
      ),
      QuoteStatus.declined => l10n.doneAddedDeclined(
        honorific,
        added.length,
        items,
      ),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = details.job;
    final finishedAt = job?.finishedAt;
    final note = _note(l10n, context.watchHonorific());
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.doneInvoiceFrom(technician),
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (finishedAt != null)
                    Text(
                      momentLabel(l10n, finishedAt),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final line in job?.items ?? const <PriceLine>[])
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      line.quantity == 1
                          ? line.title
                          : '${line.title} × ${line.quantity}',
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formatPounds(line.totalPiastres),
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
          ColoredBox(
            color: colors.background,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.invoiceTotal,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    l10n.pounds(formatPounds(job?.totalPiastres ?? 0)),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Text(
                note,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: colors.inkMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// How it was paid, the stars, the chips and a comment, then sending.
class _ReviewForm extends StatelessWidget {
  const _ReviewForm({required this.technician, required this.invoice});

  final String technician;
  final Widget invoice;

  static const _commentLimit = 500;
  static const _counterFrom = 450;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final form = context.watch<ReviewFormCubit>();
    final state = form.state;
    final busy = context.select<RequestCubit, RequestAction?>(
      (cubit) => cubit.state.busy,
    );
    final draft = state.draft;
    return Scaffold(
      appBar: DetailHeader(title: l10n.doneTitle),
      body: PullToRefresh(
        onRefresh: () => context.read<RequestCubit>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            invoice,
            const SizedBox(height: 16),
            Text(
              l10n.donePaidQuestion(honorific),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              spacing: 8,
              children: [
                for (final payment in ConsumerPayment.values)
                  Expanded(
                    child: ChoiceChipButton(
                      label: _paymentLabel(l10n, payment),
                      selected: state.paidWith == payment,
                      minHeight: 48,
                      onTap: () => form.payWith(payment),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                children: [
                  Text(
                    l10n.doneRateQuestion(firstNameOf(technician)),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _Stars(stars: state.stars, onRate: form.rate),
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 24),
                    child: Text(
                      _ratingWord(l10n, state.stars) ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in ReviewTag.values)
                        _TagChip(
                          label: _tagLabel(l10n, tag),
                          selected: state.tags.contains(tag),
                          onTap: () => form.toggleTag(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: form.writeComment,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: _commentLimit,
                    maxLengthEnforcement: MaxLengthEnforcement.enforced,
                    keyboardType: TextInputType.multiline,
                    style: const TextStyle(fontSize: 15, height: 1.6),
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => currentLength >= _counterFrom
                        ? Text('$currentLength/$maxLength')
                        : null,
                    decoration: InputDecoration(
                      hintText: l10n.doneComment(honorific),
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: colors.inkMuted,
                      ),
                      contentPadding: AppSpacing.textArea,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: BusyFilledButton(
          label: l10n.doneSubmit(honorific),
          isBusy: busy == RequestAction.review,
          onPressed: draft == null || busy != null
              ? null
              : () => context.read<RequestCubit>().submitReview(draft),
        ),
      ),
    );
  }
}

/// Five stars to tap; read-only without [onRate].
class _Stars extends StatelessWidget {
  const _Stars({required this.stars, this.onRate, this.size = 36});

  final int stars;
  final ValueChanged<int>? onRate;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final onRate = this.onRate;
    Icon star(int count) => Icon(
      Icons.star_rounded,
      size: size,
      color: count <= stars ? colors.brass : colors.border,
    );
    if (onRate == null) {
      return Semantics(
        label: l10n.doneStars(stars),
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var count = 1; count <= 5; count++) star(count)],
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var count = 1; count <= 5; count++) ...[
          if (count > 1) const SizedBox(width: 4),
          Semantics(
            selected: count == stars,
            child: IconButton(
              onPressed: () => onRate(count),
              tooltip: l10n.doneStars(count),
              constraints: const BoxConstraints.tightFor(width: 52, height: 52),
              padding: EdgeInsets.zero,
              icon: star(count),
            ),
          ),
        ],
      ],
    );
  }
}

/// A rounded chip for what the technician did well; read-only without
/// [onTap].
class _TagChip extends StatelessWidget {
  const _TagChip({required this.label, required this.selected, this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? colors.ink : colors.fieldBorder,
        width: 1.5,
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? colors.inkSoft : colors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rating as it was sent, a thank-you, and "عندي مشكلة".
class _Reviewed extends StatelessWidget {
  const _Reviewed({
    required this.details,
    required this.technician,
    required this.review,
    required this.invoice,
  });

  final RequestDetails details;
  final String technician;
  final SubmittedReview review;
  final Widget invoice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final comment = review.comment;
    return Scaffold(
      appBar: DetailHeader(title: l10n.doneTitle),
      body: PullToRefresh(
        onRefresh: () => context.read<RequestCubit>().refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            invoice,
            const SizedBox(height: 24),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colors.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 36,
                  color: colors.success,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.doneThanks,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.doneThanksBody(honorific, firstNameOf(technician)),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Column(
                children: [
                  Text(
                    l10n.doneYourRating,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Stars(stars: review.stars, size: 28),
                  Text(
                    _ratingWord(l10n, review.stars) ?? '',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.warning,
                    ),
                  ),
                  if (review.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final tag in ReviewTag.values)
                          if (review.tags.contains(tag))
                            _TagChip(
                              label: _tagLabel(l10n, tag),
                              selected: true,
                            ),
                      ],
                    ),
                  ],
                  if (comment != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      comment,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (details.hasOpenComplaint)
              const OpenComplaintNote()
            else
              Center(child: ComplaintButton(requestId: details.id)),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: () => context.go(AppRoutes.consumerHome),
          style: FilledButton.styleFrom(
            backgroundColor: colors.inkSoft,
            foregroundColor: colors.ink,
          ),
          child: Text(l10n.doneBackHome),
        ),
      ),
    );
  }
}

String _paymentLabel(AppLocalizations l10n, ConsumerPayment payment) =>
    switch (payment) {
      ConsumerPayment.cash => l10n.donePaidCash,
      ConsumerPayment.instapay => l10n.donePaidInstapay,
      ConsumerPayment.notYet => l10n.donePaidNotYet,
    };

String _tagLabel(AppLocalizations l10n, ReviewTag tag) => switch (tag) {
  ReviewTag.onTime => l10n.doneTagOnTime,
  ReviewTag.cleanWork => l10n.doneTagCleanWork,
  ReviewTag.fairPrice => l10n.doneTagFairPrice,
  ReviewTag.explained => l10n.doneTagExplained,
  ReviewTag.respectful => l10n.doneTagRespectful,
};

/// "ممتاز" for five stars; null before any.
String? _ratingWord(AppLocalizations l10n, int stars) => switch (stars) {
  1 => l10n.doneRatingAwful,
  2 => l10n.doneRatingMeh,
  3 => l10n.doneRatingGood,
  4 => l10n.doneRatingVeryGood,
  5 => l10n.doneRatingExcellent,
  _ => null,
};
