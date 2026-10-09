import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/request_issue_badge.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/standing_pill.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A request in the technician's list: what, who, where and when, its
/// offers so far and where it stands for them. Opens the request.
class IncomingRequestCard extends StatelessWidget {
  const IncomingRequestCard({
    required this.request,
    required this.standing,
    required this.now,
    super.key,
  });

  final IncomingRequest request;
  final IncomingStanding standing;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(request.categoryId)?.name,
    );
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(request.areaId),
    );
    final who = [
      request.consumerName,
      ?areaName,
      distanceLabel(l10n, request.distanceKm),
    ].join(' · ');
    final muted = TextStyle(fontSize: 14, height: 1.5, color: colors.inkMuted);

    final card = AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () => context.push(AppRoutes.incomingRequest(request.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RequestIssueBadge(issue: request.issue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        incomingTitle(l10n, request, category: category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sentAgoLabel(l10n, request.createdAt, now: now),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  who,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                Text(
                  requestDayLabel(
                    l10n,
                    request.day,
                    request.window,
                    today: now,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (standing.isLive)
                      StatusPill(
                        label: l10n.incomingOfferCount(
                          request.offerCount,
                          IncomingRequest.maxOffers,
                        ),
                        tone: PillTone.attention,
                      ),
                    if (standing != IncomingStanding.open)
                      StandingPill(request: request, standing: standing),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return standing.isClosed ? Opacity(opacity: 0.6, child: card) : card;
  }
}
