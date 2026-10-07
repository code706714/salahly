import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/requests_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/features/admin/presentation/widgets/area_filter.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The days a requests list can reach back, besides "from the start".
const _ranges = [1, 7, 30, 90];

/// Every customer request, narrowed by a search, an area, a status and how
/// far back to look.
class RequestsList extends StatelessWidget {
  const RequestsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<RequestsCubit>().state;
    final cubit = context.read<RequestsCubit>();
    final filter = state.filter;
    final now = context.watch<ClockCubit>().state;
    final colors = context.appColors;

    final Widget table;
    if (state.failure case final failure? when state.items.isEmpty) {
      table = AdminFailureView(failure: failure, onRetry: cubit.load);
    } else if (state.isLoading && state.items.isEmpty) {
      table = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.isEmpty) {
      table = AdminEmptyView(l10n.adminRequestsEmpty);
    } else {
      table = Opacity(
        opacity: state.isLoading ? 0.6 : 1,
        child: AdminTable(
          headers: [
            l10n.adminRequestsColRequest,
            l10n.adminRequestsColCustomer,
            l10n.adminRequestsColIssue,
            l10n.adminRequestsColArea,
            l10n.adminRequestsColOffers,
            l10n.adminRequestsColTechnician,
            l10n.adminRequestsColStatus,
            l10n.adminRequestsColWhen,
          ],
          flexes: const [3, 3, 3, 3, 2, 3, 4, 3],
          rows: [
            for (final request in state.items)
              AdminTableRow(
                background: request.status == AdminRequestStatus.noOffers
                    ? colors.dangerFaint
                    : null,
                cells: [
                  _Code(request),
                  Text(request.consumerName),
                  Text(requestIssueLabel(l10n, request.issue)),
                  Text(request.areaName),
                  Text('${request.offerCount}'),
                  Text(
                    request.technicianName ?? l10n.adminRequestsNoTechnician,
                  ),
                  _Status(request),
                  Text(adminAgeLabel(l10n, request.createdAt, now: now)),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: AdminSearchField(
                hint: l10n.adminRequestsSearchHint,
                initialText: filter.search,
                onChanged: (text) =>
                    cubit.filterChanged(filter.copyWith(search: text.trim())),
              ),
            ),
            AreaFilter(
              areaId: filter.areaId,
              onChanged: (areaId) =>
                  cubit.filterChanged(filter.copyWith(areaId: () => areaId)),
            ),
            AdminDropdown<AdminRequestStatus>(
              label: l10n.adminStatusFilter,
              value: filter.status,
              values: AdminRequestStatus.values,
              labelOf: (status) => adminRequestStatusLabel(l10n, status),
              allLabel: l10n.adminAllStatuses,
              onChanged: (status) =>
                  cubit.filterChanged(filter.copyWith(status: () => status)),
            ),
            AdminDropdown<int>(
              label: l10n.adminPeriodFilter,
              value: filter.days,
              values: _ranges,
              labelOf: (days) => switch (days) {
                1 => l10n.adminRequestsRangeToday,
                7 => l10n.adminRequestsRange7,
                30 => l10n.adminRequestsRange30,
                _ => l10n.adminRequestsRange90,
              },
              allLabel: l10n.adminRequestsRangeAll,
              onChanged: (days) =>
                  cubit.filterChanged(filter.copyWith(days: () => days)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              table,
              const SizedBox(height: 12),
              PagerBar.of(
                state,
                summary: l10n.adminRequestsTotal,
                onPage: cubit.goToPage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Code extends StatelessWidget {
  const _Code(this.request);

  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            request.code,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (request.hasOpenComplaint)
          Text(
            l10n.adminRequestsComplaintOpen,
            style: TextStyle(fontSize: 12, color: colors.dangerDeep),
          )
        else if (request.hasComplaint)
          Text(
            l10n.adminRequestsComplaintClosed,
            style: TextStyle(fontSize: 12, color: colors.inkMuted),
          ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.request);

  final AdminRequest request;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: adminRequestStatusLabel(
        AppLocalizations.of(context),
        request.status,
        stars: request.stars,
      ),
      tone: adminRequestStatusTone(request.status),
    );
  }
}
