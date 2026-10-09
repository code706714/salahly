import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/balance/presentation/balance_navigation.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The platform on "النهارده": new requests waiting for an offer, when
/// there are some, and the free jobs left.
class TodayRequests extends StatelessWidget {
  const TodayRequests({required this.credits, super.key});

  /// Platform jobs the technician can still take without paying.
  final int credits;

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<IncomingRequestsCubit>().state.newRequests;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (requests.isNotEmpty) ...[
          _NewRequestsCard(requests: requests, credits: credits),
          const SizedBox(height: 16),
        ],
        _CreditsRow(credits: credits),
      ],
    );
  }
}

/// "طلبين جداد في مدينة نصر": opens the requests list.
class _NewRequestsCard extends StatelessWidget {
  const _NewRequestsCard({required this.requests, required this.credits});

  final List<IncomingRequest> requests;
  final int credits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final count = requests.length;
    final areaIds = {for (final request in requests) request.areaId};
    final categoryIds = {for (final request in requests) request.categoryId};
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => areaIds.length == 1 ? cubit.state.nameOf(areaIds.first) : null,
    );
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => categoryIds.length == 1
          ? cubit.state.category(categoryIds.first)?.name
          : null,
    );
    final hint = switch (category) {
      null => null,
      _ when count == 1 => l10n.todayRequestsNeedOne(
        requests.single.consumerHonorific.name,
        category,
      ),
      _ => l10n.todayRequestsNeedMany(category),
    };

    return Material(
      color: colors.primarySoft,
      borderRadius: BorderRadius.circular(AppRadii.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.incomingRequests),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      areaName == null
                          ? l10n.todayRequestsNearby(count)
                          : l10n.todayRequestsInArea(count, areaName),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      l10n.todayRequestsCreditsLeft(credits),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: colors.primaryPressed,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

/// "رصيدك من المنصة: 1 شغلانة مجانية".
class _CreditsRow extends StatelessWidget {
  const _CreditsRow({required this.credits});

  final int credits;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: 1.5),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  children: [
                    TextSpan(text: '${l10n.todayRequestsBalance} '),
                    TextSpan(
                      text: l10n.todayRequestsBalanceCount(credits),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.openBuyUses(UserRole.technician),
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colors.primary,
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n.balanceBuy(context.watchHonorific())),
            ),
          ],
        ),
      ),
    );
  }
}
