import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/domain/repositories/withdrawal_review_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/withdrawal_review_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/withdrawals_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/admin/presentation/widgets/queue_panel.dart';
import 'package:salahly/features/admin/presentation/widgets/withdrawal/withdrawal_review_panel.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technicians' withdrawals: the queue of one step on one side, the
/// chosen request with what the team does next on the other.
class WithdrawalsPage extends StatelessWidget {
  const WithdrawalsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = WithdrawalsCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) => WithdrawalReviewCubit(
            context.read<WithdrawalReviewRepository>(),
          ),
        ),
      ],
      child: const _WithdrawalsView(),
    );
  }
}

class _WithdrawalsView extends StatefulWidget {
  const _WithdrawalsView();

  @override
  State<_WithdrawalsView> createState() => _WithdrawalsViewState();
}

class _WithdrawalsViewState extends State<_WithdrawalsView> {
  String? _selectedId;

  void _select(String? id) => setState(() => _selectedId = id);

  /// A step was taken: the request leaves this queue.
  void _changed() {
    _select(null);
    unawaited(context.read<WithdrawalsCubit>().reload());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<WithdrawalsCubit>().state;
    final cubit = context.read<WithdrawalsCubit>();
    final now = context.watch<ClockCubit>().state;
    final selected = state.items
        .where((withdrawal) => withdrawal.id == _selectedId)
        .firstOrNull;

    return AdminActionListener<WithdrawalReviewCubit>(
      onChanged: _changed,
      child: AdminPage(
        title: l10n.adminWithdrawalsTitle,
        subtitle: l10n.adminWithdrawalsSubtitle,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QueuePanel<WithdrawalReview>(
              header: AdminTabs<WithdrawalStatus?>(
                values: const [
                  WithdrawalStatus.requested,
                  WithdrawalStatus.paid,
                  WithdrawalStatus.rejected,
                  null,
                ],
                selected: state.filter.status,
                labelOf: (status) => switch (status) {
                  WithdrawalStatus.requested =>
                    l10n.adminWithdrawalsTabRequested,
                  WithdrawalStatus.paid => l10n.adminWithdrawalsTabPaid,
                  WithdrawalStatus.rejected => l10n.adminWithdrawalsTabRejected,
                  null => l10n.adminWithdrawalsTabAll,
                },
                onSelected: (status) {
                  _select(null);
                  unawaited(
                    cubit.filterChanged(WithdrawalFilter(status: status)),
                  );
                },
              ),
              state: state,
              emptyMessage: l10n.adminWithdrawalsEmpty,
              onRetry: cubit.load,
              rowBuilder: (item) => QueueTile(
                title: item.technicianName ?? l10n.adminDeletedAccount,
                subtitle: l10n.adminWithdrawalRowLine(
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
                      child: AdminEmptyView(l10n.adminWithdrawalsPickOne),
                    )
                  : WithdrawalReviewPanel(
                      key: ValueKey('${selected.id}/${selected.status}'),
                      withdrawal: selected,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
