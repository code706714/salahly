import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_profile_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/marketplace/presentation/widgets/technician_avatar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A technician's public profile: ratings, areas, prices and reviews.
///
/// Opened from [offer], it offers picking it and pops `true` when picked;
/// otherwise it offers sending this technician a new request.
class TechnicianProfilePage extends StatelessWidget {
  const TechnicianProfilePage({
    required this.technicianId,
    this.offer,
    super.key,
  });

  final String technicianId;
  final RequestOffer? offer;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = TechnicianProfileCubit(
          requests: context.read(),
          technicianId: technicianId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: TechnicianProfileView(offer: offer),
    );
  }
}

/// The page itself, reading [TechnicianProfileCubit].
class TechnicianProfileView extends StatelessWidget {
  const TechnicianProfileView({this.offer, super.key});

  /// The offer the page was opened from, to pick from here.
  final RequestOffer? offer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<TechnicianProfileCubit>().state;
    final profile = state.profile;
    if (profile == null) return _Unavailable(state: state);
    final trade = context.select<CategoriesCubit, ServiceCategory?>(
      (cubit) => _tradeOf(cubit.state.categories, profile),
    );
    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(card: profile.card, trade: trade?.name),
            // The stats card overlaps the header's bottom edge.
            Transform.translate(
              offset: const Offset(0, -14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: _Stats(profile: profile),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                4,
                AppSpacing.md,
                18,
              ),
              child: _Sections(
                profile: profile,
                trade: trade?.name,
                today: state.today,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: _MainAction(offer: offer, card: profile.card, trade: trade),
      ),
    );
  }

  /// The trade the technician works in, from the services they price;
  /// the first open trade if none of them is known yet.
  static ServiceCategory? _tradeOf(
    List<ServiceCategory> categories,
    TechnicianPublicProfile profile,
  ) {
    final services = {
      for (final service in profile.services) service.serviceId,
    };
    return categories
            .where(
              (category) => category.services.any(
                (service) => services.contains(service.id),
              ),
            )
            .firstOrNull ??
        categories.where((category) => category.isActive).firstOrNull;
  }
}

/// Loading, gone, or failed with a retry.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.state});

  final TechnicianProfileState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final failure = state.failure;
    return Scaffold(
      appBar: DetailHeader(title: l10n.techProfilePageTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: switch (state.status) {
            TechnicianProfileStatus.loading ||
            TechnicianProfileStatus.ready => const CircularProgressIndicator(),
            TechnicianProfileStatus.notFound => Text(
              l10n.techProfileNotFound,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: colors.inkMuted),
            ),
            TechnicianProfileStatus.failed => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (failure != null)
                  Text(
                    consumerFailureMessage(
                      l10n,
                      failure,
                      honorific: honorific,
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: colors.inkMuted),
                  ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: context.read<TechnicianProfileCubit>().load,
                  child: Text(l10n.consumerRetry(honorific)),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

/// The dark top: back, the avatar, name, trade and years, and verified.
class _Header extends StatelessWidget {
  const _Header({required this.card, required this.trade});

  final TechnicianCard card;

  /// The trade's name, once the categories load.
  final String? trade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final trade = this.trade;
    return ColoredBox(
      color: colors.ink,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButtonTheme(
                data: IconButtonThemeData(
                  style: IconButton.styleFrom(
                    foregroundColor: colors.background,
                  ),
                ),
                child: AppBackButton(
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    TechnicianAvatar(name: card.name, size: 76, ring: 3),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            card.name,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                              color: colors.background,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (trade != null) l10n.techProfileTrade(trade),
                              l10n.techProfileYears(card.yearsExperience),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.onInkMuted,
                            ),
                          ),
                          if (card.verified) ...[
                            const SizedBox(height: 4),
                            _VerifiedPill(label: l10n.techProfileVerified),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brass,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_outlined, size: 15, color: colors.ink),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rating, jobs done and how often they came on time; a stat with nothing
/// to show yet is left out.
class _Stats extends StatelessWidget {
  const _Stats({required this.profile});

  final TechnicianPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final card = profile.card;
    final rating = card.rating;
    final onTime = profile.onTimePercent;
    final stats = [
      if (rating != null)
        _Stat(
          value: rating.toStringAsFixed(1),
          star: true,
          label: l10n.techProfileReviewCount(card.reviewCount),
        ),
      _Stat(
        value: '${card.jobsDone}',
        label: l10n.techProfileJobsDone(card.jobsDone),
      ),
      if (onTime != null)
        _Stat(
          value: l10n.techProfileOnTimeValue(onTime),
          label: l10n.techProfileOnTime,
        ),
    ];
    return AppCard(
      radius: AppRadii.lg,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (final (index, stat) in stats.indexed) ...[
              if (index > 0) VerticalDivider(width: 1, color: colors.divider),
              Expanded(child: stat),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.star = false});

  final String value;
  final String label;
  final bool star;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (star) ...[
                Icon(Icons.star_rounded, size: 18, color: colors.brass),
                const SizedBox(width: 4),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: colors.ink,
                ),
              ),
            ],
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Where they work, their starting prices and the reviews.
class _Sections extends StatelessWidget {
  const _Sections({
    required this.profile,
    required this.trade,
    required this.today,
  });

  final TechnicianPublicProfile profile;

  /// The trade's name, once the categories load.
  final String? trade;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final areas = context.watch<AreasCubit>().state;
    final categories = context.watch<CategoriesCubit>().state;
    final areaNames = [
      for (final id in profile.areaIds) ?areas.nameOf(id),
    ];
    final prices = [
      for (final service in profile.services)
        if (categories.serviceName(service.serviceId) case final name?)
          (name, service.startingPricePiastres),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (areaNames.isNotEmpty) ...[
          _SectionTitle(l10n.techProfileAreas),
          const SizedBox(height: 10),
          Text(
            areaNames.join('، '),
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.ink),
          ),
          const SizedBox(height: 18),
        ],
        if (prices.isNotEmpty) ...[
          _SectionTitle(l10n.techProfilePrices),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            radius: AppRadii.lg,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (index, (name, piastres)) in prices.indexed) ...[
                  if (index > 0) const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.techProfileFromPrice(
                            l10n.pounds(formatPounds(piastres)),
                          ),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                            color: colors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        _Reviews(reviews: profile.reviews, trade: trade, today: today),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

/// "رأي العملاء": the newest two, and the rest on "كل التقييمات".
class _Reviews extends StatefulWidget {
  const _Reviews({
    required this.reviews,
    required this.trade,
    required this.today,
  });

  final List<PublicReview> reviews;
  final String? trade;
  final DateTime today;

  @override
  State<_Reviews> createState() => _ReviewsState();
}

class _ReviewsState extends State<_Reviews> {
  static const _shownFirst = 2;
  bool _showsAll = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final reviews = widget.reviews;
    final hasMore = !_showsAll && reviews.length > _shownFirst;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(l10n.techProfileReviews)),
            if (hasMore)
              TextButton(
                onPressed: () => setState(() => _showsAll = true),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(l10n.techProfileAllReviews),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (reviews.isEmpty)
          Text(
            l10n.techProfileNoReviews,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          )
        else
          for (final (index, review)
              in (hasMore ? reviews.take(_shownFirst) : reviews).indexed) ...[
            if (index > 0) const SizedBox(height: 10),
            _ReviewCard(
              review: review,
              category: widget.trade,
              today: widget.today,
            ),
          ],
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.category,
    required this.today,
  });

  final PublicReview review;
  final String? category;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final comment = review.comment;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.author,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: colors.ink,
                  ),
                ),
              ),
              _Stars(stars: review.stars),
            ],
          ),
          if (comment != null) ...[
            const SizedBox(height: 6),
            Text(
              comment,
              style: TextStyle(fontSize: 15, height: 1.7, color: colors.ink),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${requestHeadline(l10n, review.issue, category: category)} · '
            '${reviewAgoLabel(l10n, review.createdAt, today: today)}',
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      label: AppLocalizations.of(context).techProfileStars(stars),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var star = 1; star <= 5; star++)
              Icon(
                Icons.star_rounded,
                size: 18,
                color: star <= stars ? colors.brass : colors.border,
              ),
          ],
        ),
      ),
    );
  }
}

/// Picking the offer the page was opened from, or asking this technician.
class _MainAction extends StatelessWidget {
  const _MainAction({
    required this.offer,
    required this.card,
    required this.trade,
  });

  final RequestOffer? offer;
  final TechnicianCard card;
  final ServiceCategory? trade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.watchHonorific();
    final name = firstNameOf(card.name);
    final offer = this.offer;
    return FilledButton(
      onPressed: offer != null
          ? () => Navigator.of(context).pop(true)
          : () => unawaited(
              context.push(
                AppRoutes.newRequestFor(
                  categoryId: trade?.id,
                  technicianId: card.id,
                ),
              ),
            ),
      child: Text(
        offer != null
            ? l10n.techProfilePickOffer(
                honorific,
                name,
                l10n.pounds(formatPounds(offer.pricePiastres)),
              )
            : l10n.techProfileAsk(honorific, name),
      ),
    );
  }
}
