import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/offer_sort.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/confirm_choice_dialog.dart';
import 'package:salahly/features/marketplace/presentation/widgets/technician_avatar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The offers to choose from, sortable, each opening its technician.
class OffersView extends StatelessWidget {
  const OffersView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ClockCubit()..start(),
      child: _OffersScreen(details: details),
    );
  }
}

class _OffersScreen extends StatefulWidget {
  const _OffersScreen({required this.details});

  final RequestDetails details;

  @override
  State<_OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<_OffersScreen> {
  OfferSort _sort = OfferSort.nearest;

  /// The offer being picked, which shows the progress.
  String? _picking;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final details = widget.details;
    final today = context.watch<ClockCubit>().state;
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(details.categoryId)?.name,
    );
    final busy = context.select<RequestCubit, RequestAction?>(
      (cubit) => cubit.state.busy,
    );
    final headline = requestHeadline(l10n, details.issue, category: category);
    final when =
        '${requestDayName(l10n, details.day, today: today)} '
        '${requestWindowLabel(l10n, details.window)}';
    return Scaffold(
      appBar: DetailHeader(
        title: l10n.offersTitle,
        subtitle: '$headline · $when',
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.offersReceived(
              details.offers.length,
              max(details.sentTo, details.offers.length),
            ),
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final sort in OfferSort.values)
                _SortChip(
                  label: switch (sort) {
                    OfferSort.nearest => l10n.offersSortNearest,
                    OfferSort.cheapest => l10n.offersSortCheapest,
                    OfferSort.topRated => l10n.offersSortTopRated,
                  },
                  selected: sort == _sort,
                  onTap: () => setState(() => _sort = sort),
                ),
            ],
          ),
          for (final offer in sortOffers(details.offers, _sort)) ...[
            const SizedBox(height: 14),
            _OfferCard(
              offer: offer,
              today: today,
              picking:
                  busy == RequestAction.acceptOffer && _picking == offer.id,
              onProfile: busy == null ? () => _openProfile(offer) : null,
              onPick: busy == null ? () => _confirmPick(offer, today) : null,
            ),
          ],
          const SizedBox(height: 14),
          const _PricesNote(),
        ],
      ),
    );
  }

  Future<void> _openProfile(RequestOffer offer) async {
    final picked = await context.push<bool>(
      AppRoutes.technicianProfile(offer.technician.id),
      extra: offer,
    );
    if ((picked ?? false) && mounted) await _accept(offer);
  }

  Future<void> _confirmPick(RequestOffer offer, DateTime today) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final name = firstNameOf(offer.technician.name);
    final confirmed = await showConfirmChoiceDialog(
      context,
      title: l10n.offersPickTitle(honorific, name),
      body: l10n.offersPickBody(
        '${requestDayName(l10n, offer.arriveAt, today: today)} '
        '${timeLabel(l10n, offer.arriveAt)}',
        l10n.pounds(formatPounds(offer.pricePiastres)),
      ),
      keep: l10n.offersPickKeep(honorific),
      confirm: l10n.offersPick(honorific, name),
    );
    if (confirmed && mounted) await _accept(offer);
  }

  Future<void> _accept(RequestOffer offer) async {
    final cubit = context.read<RequestCubit>();
    setState(() => _picking = offer.id);
    await cubit.acceptOffer(offer.id);
    if (mounted) setState(() => _picking = null);
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.ink : colors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? colors.background : colors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One offer: who, how much, when, how far, their note, and the choices.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.today,
    required this.picking,
    required this.onProfile,
    required this.onPick,
  });

  final RequestOffer offer;
  final DateTime today;
  final bool picking;

  /// Null while another action runs.
  final VoidCallback? onProfile;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final technician = offer.technician;
    final note = offer.note;
    final distance = offer.distanceKm;
    final arrival =
        '${requestDayName(l10n, offer.arriveAt, today: today)} '
        '${clockTime(offer.arriveAt)}';
    return AppCard(
      radius: AppRadii.xxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TechnicianAvatar(name: technician.name, size: 56),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            technician.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                              color: colors.ink,
                            ),
                          ),
                        ),
                        if (technician.verified) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: colors.warning,
                            semanticLabel: l10n.offersVerified,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    _TechnicianRecord(technician: technician),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.offersStartingPrice,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: colors.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        MoneyText(
                          offer.pricePiastres,
                          currencyScale: 15 / 26,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: colors.ink,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            arrival,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.ink,
                            ),
                          ),
                        ],
                      ),
                      if (distance != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.offersDistance(distance.toStringAsFixed(1)),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.offersNote(note),
              style: TextStyle(fontSize: 14, height: 1.6, color: colors.ink),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onProfile,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.ink,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    side: BorderSide(color: colors.fieldBorder, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: Text(l10n.offersProfile),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: picking ? () {} : onPick,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: picking
                      ? SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(
                          l10n.offersPick(
                            context.watchHonorific(),
                            firstNameOf(technician.name),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "★ 4.9 (31 تقييم) · 40 شغلانة".
class _TechnicianRecord extends StatelessWidget {
  const _TechnicianRecord({required this.technician});

  final TechnicianCard technician;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final rating = technician.rating;
    final jobs = l10n.offersJobsDone(technician.jobsDone);
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 14, height: 1.5, color: colors.inkMuted),
        children: [
          if (rating == null)
            TextSpan(text: '${l10n.offersNoReviews} · $jobs')
          else ...[
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 4),
                child: Icon(Icons.star_rounded, size: 17, color: colors.brass),
              ),
            ),
            TextSpan(
              text: rating.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.w700, color: colors.ink),
            ),
            TextSpan(
              text:
                  ' ${l10n.offersReviewCount(technician.reviewCount)} · $jobs',
            ),
          ],
        ],
      ),
    );
  }
}

class _PricesNote extends StatelessWidget {
  const _PricesNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: colors.inkMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.offersPricesNote(context.watchHonorific()),
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
