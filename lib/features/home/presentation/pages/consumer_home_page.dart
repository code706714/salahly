import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/balance/presentation/balance_navigation.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/presentation/category_icon.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/home/presentation/cubit/consumer_home_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/notifications/presentation/widgets/notifications_bell.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumer's start screen: their newest request in progress, the
/// categories with the technicians nearby, and the button to ask for one.
class ConsumerHomePage extends StatelessWidget {
  const ConsumerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ConsumerHomeCubit(
        requests: context.read(),
        areaId: switch (context.read<SessionCubit>().state) {
          SessionReady(:final profile) => profile.consumer?.areaId,
          _ => null,
        },
      )..useCategories(context.read<CategoriesCubit>().state.categories),
      child: const ConsumerHomeView(),
    );
  }
}

class ConsumerHomeView extends StatelessWidget {
  const ConsumerHomeView({super.key});

  Future<void> _refresh(BuildContext context) => Future.wait([
    context.read<ConsumerHomeCubit>().refresh(),
    context.read<MyRequestsCubit>().load(),
  ]);

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    final consumer = profile?.consumer;
    // Briefly null while signing out, before the redirect.
    if (profile == null || consumer == null) return const Scaffold();
    final state = context.watch<ConsumerHomeCubit>().state;
    final latest = context.select<MyRequestsCubit, RequestSummary?>(
      (cubit) => cubit.state.active.firstOrNull,
    );
    final selected = state.selected;

    return BlocListener<CategoriesCubit, CategoriesState>(
      listener: (context, categories) => context
          .read<ConsumerHomeCubit>()
          .useCategories(categories.categories),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => _refresh(context),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    16,
                    20,
                    16,
                    selected == null ? 24 : 120,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(child: _AreaName(consumer.areaName)),
                        const SizedBox(width: 12),
                        const NotificationsBell(role: UserRole.consumer),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _Greeting(firstName: profile.firstName),
                    const SizedBox(height: 18),
                    _CreditsLeft(consumer.requestCredits),
                    if (latest != null) ...[
                      const SizedBox(height: 18),
                      _LatestRequest(request: latest),
                    ],
                    if (state.categories.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _Categories(state: state),
                    ],
                    const SizedBox(height: 18),
                    const _WhyHere(),
                  ],
                ),
              ),
              if (selected != null)
                PositionedDirectional(
                  start: 16,
                  end: 16,
                  bottom: 16,
                  child: _RequestButton(category: selected),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The consumer's area. Changing it isn't offered, so it isn't a button.
class _AreaName extends StatelessWidget {
  const _AreaName(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    // As tall as the design's header row.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: colors.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      header: true,
      child: Text(
        '${l10n.greeting(firstName)}\n'
        '${l10n.consumerHomeQuestion(context.watchHonorific())}',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}

/// "فاضل ليكي طلب واحد ببلاش".
class _CreditsLeft extends StatelessWidget {
  const _CreditsLeft(this.credits);

  final int credits;

  /// From this many uses left, the card offers to buy more.
  static const lowCredits = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    const bold = TextStyle(fontWeight: FontWeight.w700);
    final low = credits <= lowCredits;
    return AppCard(
      radius: AppRadii.md,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: low ? () => context.openBuyUses(UserRole.consumer) : null,
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 14, color: colors.ink),
                children: credits > 0
                    ? [
                        TextSpan(
                          text: l10n.consumerHomeCreditsLead(
                            context.watchHonorific(),
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: l10n.consumerHomeCreditsCount(credits),
                          style: bold,
                        ),
                      ]
                    : [
                        TextSpan(
                          text: l10n.consumerCreditsLeft(0),
                          style: bold,
                        ),
                      ],
              ),
            ),
          ),
          if (low) ...[
            const SizedBox(width: 10),
            Text(
              l10n.buyUsesTopUp(context.watchHonorific()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The newest request still in progress, on the dark banner.
class _LatestRequest extends StatelessWidget {
  const _LatestRequest({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(request.categoryId)?.name,
    );
    final title = category == null
        ? requestIssueLabel(l10n, request.issue)
        : requestTitle(l10n, request.issue, category: category);
    final action = request.stage == RequestStage.choosingOffer
        ? l10n.consumerHomeSeeOffers(honorific)
        : l10n.consumerHomeFollow(honorific);
    return Material(
      color: colors.ink,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.request(request.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.consumerHomeRequestLabel(title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.onInkMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _progress(l10n, honorific),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: colors.background,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: colors.brass,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  action,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Where the request stands, in a line.
  String _progress(AppLocalizations l10n, String honorific) {
    final technician =
        request.technicianName?.split(' ').first ??
        l10n.consumerHomeTechnicianFallback;
    final scheduledAt = request.scheduledAt;
    return switch (request.stage) {
      RequestStage.waitingForOffers => l10n.consumerHomeWaiting,
      RequestStage.choosingOffer => l10n.consumerHomeOffers(
        request.offerCount,
        honorific,
      ),
      RequestStage.chosen => l10n.consumerHomeChosen(honorific, technician),
      RequestStage.confirmed when scheduledAt != null =>
        l10n.consumerHomeComing(
          technician,
          dayLabel(l10n, scheduledAt, today: DateTime.now()),
          timeLabel(l10n, scheduledAt),
        ),
      RequestStage.confirmed => l10n.consumerHomeConfirmed(technician),
      RequestStage.started => l10n.consumerHomeStarted(technician),
      // Only requests in progress reach the banner.
      RequestStage.done ||
      RequestStage.cancelled ||
      RequestStage.expired => l10n.consumerHomeFollow(honorific),
    };
  }
}

/// The categories, two a row: open ones can be picked for the request
/// button, the rest are coming soon.
class _Categories extends StatelessWidget {
  const _Categories({required this.state});

  final ConsumerHomeState state;

  @override
  Widget build(BuildContext context) {
    final categories = state.categories;
    return Column(
      children: [
        for (var start = 0; start < categories.length; start += 2) ...[
          if (start > 0) const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = start; i < start + 2; i++) ...[
                  if (i > start) const SizedBox(width: 10),
                  Expanded(
                    child: i < categories.length
                        ? _CategoryTile(
                            category: categories[i],
                            selected: categories[i].id == state.selectedId,
                            technicians:
                                state.technicianCounts[categories[i].id],
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.technicians,
  });

  final ServiceCategory category;
  final bool selected;

  /// Technicians nearby, once counted.
  final int? technicians;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final open = category.isActive;
    final technicians = this.technicians;
    final note = !open
        ? l10n.consumerHomeSoon
        : technicians == null
        ? ''
        : l10n.consumerHomeTechnicians(technicians);
    return Semantics(
      button: open,
      selected: selected,
      child: Opacity(
        opacity: open ? 1 : 0.62,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 112),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: selected ? colors.primary : null,
            borderWidth: selected ? 2 : 1.5,
            onTap: open
                ? () => context.read<ConsumerHomeCubit>().select(category.id)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: open ? colors.primarySoft : colors.divider,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    categoryIcon(category.id),
                    size: 28,
                    color: open ? colors.primary : colors.inkMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                  ),
                ),
                Text(
                  note,
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Why ask here: verified technicians, real reviews, the price up front.
class _WhyHere extends StatelessWidget {
  const _WhyHere();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    Widget reason(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ),
      ],
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.consumerHomeWhyTitle(honorific),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          reason(
            Icons.verified_user_outlined,
            colors.warning,
            l10n.consumerHomeWhyVerified,
          ),
          const SizedBox(height: 12),
          reason(Icons.star_rounded, colors.brass, l10n.consumerHomeWhyReviews),
          const SizedBox(height: 12),
          reason(
            Icons.credit_card_rounded,
            colors.warning,
            l10n.consumerHomeWhyPrice(honorific),
          ),
        ],
      ),
    );
  }
}

/// "اطلبي فني تكييف", floating over the bottom of the screen.
class _RequestButton extends StatelessWidget {
  const _RequestButton({required this.category});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: colors.ink.withValues(alpha: 0.22),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: () => context.push(
          AppRoutes.newRequestFor(categoryId: category.id),
        ),
        child: Text(
          l10n.newRequestTitle(context.watchHonorific(), category.name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
