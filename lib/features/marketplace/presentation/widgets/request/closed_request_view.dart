import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A cancelled or expired request, and asking again.
class ClosedRequestView extends StatelessWidget {
  const ClosedRequestView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(details.categoryId)?.name,
    );
    final area = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(details.areaId),
    );
    final (icon, title, body) = switch (details.stage) {
      RequestStage.cancelled when details.cancelledBy == UserRole.technician =>
        (
          Icons.event_busy_outlined,
          l10n.closedRequestCancelledByTechnician,
          l10n.closedRequestAskOthers(honorific),
        ),
      RequestStage.cancelled => (
        Icons.event_busy_outlined,
        l10n.closedRequestCancelledByYou(honorific),
        details.chosenOfferId == null
            ? l10n.closedRequestFreeCancel
            : l10n.closedRequestTechnicianTold,
      ),
      _ when details.offers.isEmpty => (
        Icons.hourglass_empty_rounded,
        l10n.closedRequestExpiredNoOffers,
        l10n.closedRequestTryAnotherTime(honorific),
      ),
      _ => (
        Icons.hourglass_empty_rounded,
        l10n.closedRequestExpiredNoPick(honorific),
        l10n.closedRequestTryAnotherTime(honorific),
      ),
    };
    return Scaffold(
      appBar: DetailHeader(
        title: requestHeadline(l10n, details.issue, category: category),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
            child: Column(
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: colors.inkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 40, color: colors.inkMuted),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _SummaryLine(
                  icon: Icons.event_outlined,
                  text:
                      '${weekdayDate(details.day)} · '
                      '${requestWindowLabel(l10n, details.window)}',
                ),
                const SizedBox(height: AppSpacing.sm),
                _SummaryLine(
                  icon: Icons.location_on_outlined,
                  text: [details.addressLabel, ?area].join(' · '),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: FilledButton(
          onPressed: () => unawaited(
            context.push(
              AppRoutes.newRequestFor(categoryId: details.categoryId),
            ),
          ),
          child: Text(l10n.closedRequestAgain(honorific)),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(icon, size: 22, color: colors.inkMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.ink),
          ),
        ),
      ],
    );
  }
}
