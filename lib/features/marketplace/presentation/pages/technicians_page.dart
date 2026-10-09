import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/category_icon.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_directory_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/load_failed_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/marketplace/presentation/widgets/technician_avatar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The "الفنيين" tab: verified technicians to browse by trade and area,
/// ordered by rating, reviews, experience, jobs or price.
class TechniciansPage extends StatelessWidget {
  const TechniciansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = TechnicianDirectoryCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const TechniciansView(),
    );
  }
}

class TechniciansView extends StatelessWidget {
  const TechniciansView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TechnicianDirectoryCubit>();
    final state = context.watch<TechnicianDirectoryCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: switch (state.status) {
          TechnicianDirectoryStatus.failed => Column(
            children: [
              const _Header(),
              Expanded(
                child: LoadFailedView(
                  message: consumerFailureMessage(
                    l10n,
                    state.failure!,
                    honorific: context.watchHonorific(),
                  ),
                  retryLabel: l10n.consumerRetry(context.watchHonorific()),
                  onRetry: cubit.load,
                ),
              ),
            ],
          ),
          _ => NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 200) {
                unawaited(cubit.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const _Header(),
                  const SizedBox(height: 14),
                  const _Filters(),
                  const SizedBox(height: 14),
                  if (state.status == TechnicianDirectoryStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.technicians.isEmpty)
                    const _Empty()
                  else ...[
                    for (final listing in state.technicians) ...[
                      _TechnicianTile(listing: listing),
                      const SizedBox(height: 12),
                    ],
                    if (state.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ],
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Semantics(
        header: true,
        child: Text(
          l10n.directoryTitle,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// Trade chips, the area button and the sort chips.
class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianDirectoryCubit>();
    final state = context.watch<TechnicianDirectoryCubit>().state;
    final categories = [
      for (final category in context.watch<CategoriesCubit>().state.categories)
        if (category.isActive) category,
    ];
    final areas = context.watch<AreasCubit>().state.areas;
    final area = areas.where((area) => area.id == state.areaId).firstOrNull;

    Future<void> pickArea() async {
      final picked = await showAreaPicker(context, areas: areas);
      if (picked != null) await cubit.selectArea(picked.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 10,
      children: [
        _ChipRow(
          children: [
            ChoiceChipButton(
              label: l10n.directoryAll,
              selected: state.categoryId == null,
              onTap: () => cubit.selectCategory(null),
            ),
            for (final category in categories)
              ChoiceChipButton(
                label: category.name,
                icon: categoryIcon(category.id),
                selected: state.categoryId == category.id,
                onTap: () => cubit.selectCategory(category.id),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: areas.isEmpty ? null : pickArea,
                icon: const Icon(Icons.location_on_outlined, size: 20),
                label: Text(
                  area?.name ?? l10n.directoryAllAreas,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.ink,
                  minimumSize: const Size.fromHeight(44),
                  side: BorderSide(color: colors.fieldBorder, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
              ),
            ),
            if (area != null)
              IconButton(
                tooltip: l10n.directoryAllAreas,
                onPressed: () => cubit.selectArea(null),
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
        _ChipRow(
          children: [
            for (final sort in TechnicianSort.values)
              ChoiceChipButton(
                label: switch (sort) {
                  TechnicianSort.rating => l10n.directorySortRating,
                  TechnicianSort.reviews => l10n.directorySortReviews,
                  TechnicianSort.experience => l10n.directorySortExperience,
                  TechnicianSort.jobs => l10n.directorySortJobs,
                  TechnicianSort.price => l10n.directorySortPrice,
                },
                selected: state.sort == sort,
                inkWhenSelected: true,
                onTap: () => cubit.selectSort(sort),
              ),
          ],
        ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 8, children: children),
    );
  }
}

class _TechnicianTile extends StatelessWidget {
  const _TechnicianTile({required this.listing});

  final TechnicianListing listing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final card = listing.card;
    final rating = card.rating;
    final minPrice = listing.minPricePiastres;
    final facts = [
      l10n.techProfileYears(card.yearsExperience),
      l10n.offersJobsDone(card.jobsDone),
    ].join(' · ');
    return AppCard(
      onTap: () => context.push(AppRoutes.technicianProfile(card.id)),
      child: Row(
        children: [
          TechnicianAvatar(name: card.name, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        card.name,
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
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: colors.warning,
                      semanticLabel: l10n.offersVerified,
                    ),
                  ],
                ),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.inkMuted,
                    ),
                    children: [
                      if (rating == null)
                        TextSpan(text: l10n.offersNoReviews)
                      else ...[
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: 17,
                              color: colors.brass,
                            ),
                          ),
                        ),
                        TextSpan(
                          text: rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: colors.ink,
                          ),
                        ),
                        TextSpan(
                          text: ' ${l10n.offersReviewCount(card.reviewCount)}',
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  facts,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          if (minPrice != null) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  l10n.priceFrom,
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
                MoneyText(
                  minPrice,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: colors.inkMuted),
          const SizedBox(height: 12),
          Text(
            l10n.directoryEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.directoryEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
