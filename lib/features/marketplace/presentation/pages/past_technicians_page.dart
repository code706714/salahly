import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technicians the consumer hired before, to ask again.
///
/// Built from the requests list above every consumer screen, so it has no
/// cubit of its own.
class PastTechniciansPage extends StatelessWidget {
  const PastTechniciansPage({super.key});

  /// Each picked technician once, with their latest request; [requests]
  /// are newest first.
  static List<PastTechnician> fromRequests(List<RequestSummary> requests) {
    final seen = <String>{};
    return [
      for (final request in requests)
        if (request.technicianId case final id? when seen.add(id))
          (id: id, lastRequest: request),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final state = context.watch<MyRequestsCubit>().state;
    final technicians = fromRequests(state.requests);

    return Scaffold(
      appBar: DetailHeader(title: l10n.pastTechniciansTitle),
      body: switch (state.status) {
        MyRequestsStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        MyRequestsStatus.failed => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.pastTechniciansLoadFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: colors.inkMuted),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: context.read<MyRequestsCubit>().load,
                  child: Text(l10n.consumerRetry(honorific)),
                ),
              ],
            ),
          ),
        ),
        MyRequestsStatus.ready when technicians.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.engineering_outlined,
                  size: 40,
                  color: colors.inkMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.pastTechniciansEmpty(honorific),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.pastTechniciansEmptyNote(honorific),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        MyRequestsStatus.ready => PullToRefresh(
          onRefresh: context.read<MyRequestsCubit>().load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, technician) in technicians.indexed) ...[
                      if (index > 0) const Divider(),
                      _TechnicianRow(technician: technician),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      },
    );
  }
}

/// A technician the consumer picked, and the last request they took.
typedef PastTechnician = ({String id, RequestSummary lastRequest});

class _TechnicianRow extends StatelessWidget {
  const _TechnicianRow({required this.technician});

  final PastTechnician technician;

  @override
  Widget build(BuildContext context) {
    final request = technician.lastRequest;
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final name = request.technicianName ?? l10n.consumerHomeTechnicianFallback;
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(request.categoryId)?.name,
    );
    final title = category == null
        ? requestIssueLabel(l10n, request.issue)
        : requestTitle(l10n, request.issue, category: category);
    return InkWell(
      onTap: () => context.push(AppRoutes.technicianProfile(technician.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(name: name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                      color: colors.ink,
                    ),
                  ),
                  Text(
                    l10n.pastTechniciansLastRequest(
                      title,
                      DateFormat('d MMMM yyyy', 'ar').format(request.day),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: colors.dashedBorder,
            ),
          ],
        ),
      ),
    );
  }
}
