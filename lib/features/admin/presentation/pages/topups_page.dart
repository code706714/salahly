import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/topup_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/topups_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/admin/presentation/widgets/queue_panel.dart';
import 'package:salahly/features/admin/presentation/widgets/topups/topup_review_panel.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The transfers people sent to buy uses: the queue on one side, the chosen
/// transfer with its screenshot on the other.
class TopupsPage extends StatelessWidget {
  const TopupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = TopupsCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) =>
              TopupReviewCubit(context.read<TopupReviewRepository>()),
        ),
      ],
      child: const _TopupsView(),
    );
  }
}

class _TopupsView extends StatefulWidget {
  const _TopupsView();

  @override
  State<_TopupsView> createState() => _TopupsViewState();
}

class _TopupsViewState extends State<_TopupsView> {
  String? _selectedId;

  void _select(String? id) => setState(() => _selectedId = id);

  /// A transfer was reviewed: it leaves the queue and the counts move.
  void _reviewed() {
    _select(null);
    unawaited(context.read<TopupsCubit>().reload());
    unawaited(context.read<OverviewCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<TopupsCubit>().state;
    final cubit = context.read<TopupsCubit>();
    final now = context.watch<ClockCubit>().state;
    final pendingCount = context.select<OverviewCubit, int?>(
      (cubit) => cubit.state.overview?.pendingTopups.count,
    );
    final selected = state.items
        .where((topup) => topup.id == _selectedId)
        .firstOrNull;

    return AdminActionListener<TopupReviewCubit>(
      onChanged: _reviewed,
      child: AdminPage(
        title: l10n.adminTopupsTitle,
        subtitle: pendingCount == null
            ? l10n.adminTopupsSubtitle
            : '${l10n.adminTopupsPendingCount(pendingCount)} · '
                  '${l10n.adminTopupsSubtitle}',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QueuePanel<TopupReview>(
              header: AdminTabs<TopupStatus?>(
                values: const [
                  TopupStatus.pending,
                  TopupStatus.approved,
                  TopupStatus.rejected,
                  null,
                ],
                selected: state.filter.status,
                labelOf: (status) => switch (status) {
                  TopupStatus.pending => l10n.adminTopupsTabPending,
                  TopupStatus.approved => l10n.adminTopupsTabApproved,
                  TopupStatus.rejected => l10n.adminTopupsTabRejected,
                  null => l10n.adminTopupsTabAll,
                },
                onSelected: (status) {
                  _select(null);
                  unawaited(
                    cubit.filterChanged(
                      state.filter.copyWith(status: () => status),
                    ),
                  );
                },
              ),
              state: state,
              emptyMessage: state.filter.status == TopupStatus.pending
                  ? l10n.adminTopupsEmptyPending
                  : l10n.adminTopupsEmpty,
              onRetry: cubit.load,
              rowBuilder: (item) => QueueTile(
                title: item.name ?? l10n.adminDeletedAccount,
                subtitle: l10n.adminTopupsRowLine(
                  topupMethodLabel(l10n, item.method),
                  adminAgeLabel(l10n, item.createdAt, now: now),
                ),
                selected: item.id == _selectedId,
                onTap: () => _select(item.id),
              ),
              footer: PagerBar.of(
                state,
                summary: l10n.adminRowsOfTotal,
                onPage: cubit.goToPage,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: selected == null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: AdminEmptyView(l10n.adminTopupsPickOne),
                    )
                  : TopupReviewPanel(
                      key: ValueKey(selected.id),
                      topup: selected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
