import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/repositories/escrow_review_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/escrow_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/escrows_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/escrow/escrow_review_panel.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/admin/presentation/widgets/queue_panel.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumers' guaranteed payments: the queue of one step on one side,
/// the chosen payment with what the team does next on the other.
class EscrowPage extends StatelessWidget {
  const EscrowPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = EscrowsCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) =>
              EscrowReviewCubit(context.read<EscrowReviewRepository>()),
        ),
      ],
      child: const _EscrowView(),
    );
  }
}

class _EscrowView extends StatefulWidget {
  const _EscrowView();

  @override
  State<_EscrowView> createState() => _EscrowViewState();
}

class _EscrowViewState extends State<_EscrowView> {
  String? _selectedId;

  void _select(String? id) => setState(() => _selectedId = id);

  /// A step was taken: the payment leaves this queue.
  void _changed() {
    _select(null);
    unawaited(context.read<EscrowsCubit>().reload());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<EscrowsCubit>().state;
    final cubit = context.read<EscrowsCubit>();
    final now = context.watch<ClockCubit>().state;
    final selected = state.items
        .where((escrow) => escrow.id == _selectedId)
        .firstOrNull;

    return AdminActionListener<EscrowReviewCubit>(
      onChanged: _changed,
      child: AdminPage(
        title: l10n.adminEscrowTitle,
        subtitle: l10n.adminEscrowSubtitle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QueuePanel<EscrowReview>(
              header: AdminTabs<EscrowStatus?>(
                tabPadding: 8,
                values: const [
                  EscrowStatus.pending,
                  EscrowStatus.released,
                  EscrowStatus.disputed,
                  EscrowStatus.refundDue,
                  null,
                ],
                selected: state.filter.status,
                labelOf: (status) => switch (status) {
                  EscrowStatus.pending => l10n.adminEscrowTabPending,
                  EscrowStatus.released => l10n.adminEscrowTabReleased,
                  EscrowStatus.disputed => l10n.adminEscrowTabDisputed,
                  EscrowStatus.refundDue => l10n.adminEscrowTabRefundDue,
                  _ => l10n.adminEscrowTabAll,
                },
                onSelected: (status) {
                  _select(null);
                  unawaited(cubit.filterChanged(EscrowFilter(status: status)));
                },
              ),
              state: state,
              emptyMessage: l10n.adminEscrowEmpty,
              onRetry: cubit.load,
              rowBuilder: (item) => QueueTile(
                title: item.consumerName ?? l10n.adminDeletedAccount,
                subtitle: l10n.adminEscrowRowLine(
                  item.requestCode,
                  formatPounds(item.amountPiastres),
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
                      child: AdminEmptyView(l10n.adminEscrowPickOne),
                    )
                  : EscrowReviewPanel(
                      key: ValueKey('${selected.id}/${selected.status}'),
                      escrow: selected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
