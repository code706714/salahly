import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_queue_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/admin/presentation/widgets/queue_panel.dart';
import 'package:salahly/features/admin/presentation/widgets/verification/verification_review.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technicians' ID submissions: the queue on one side, the chosen
/// submission with its photos on the other.
class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = VerificationQueueCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _VerificationView(),
    );
  }
}

class _VerificationView extends StatefulWidget {
  const _VerificationView();

  @override
  State<_VerificationView> createState() => _VerificationViewState();
}

class _VerificationViewState extends State<_VerificationView> {
  String? _selectedId;

  void _select(String? id) => setState(() => _selectedId = id);

  /// A submission was reviewed: it leaves the queue and the counts move.
  void _reviewed() {
    _select(null);
    unawaited(context.read<VerificationQueueCubit>().reload());
    unawaited(context.read<OverviewCubit>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<VerificationQueueCubit>().state;
    final cubit = context.read<VerificationQueueCubit>();
    final now = context.watch<ClockCubit>().state;
    final pendingCount = context.select<OverviewCubit, int?>(
      (cubit) => cubit.state.overview?.pendingVerifications.count,
    );

    return AdminPage(
      title: l10n.adminVerifyTitle,
      subtitle: pendingCount == null
          ? l10n.adminVerifySubtitle
          : '${l10n.adminVerifyPendingCount(pendingCount)} · '
                '${l10n.adminVerifySubtitle}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QueuePanel<VerificationSummary>(
            header: AdminTabs<VerificationStatus>(
              values: VerificationStatus.values,
              selected: state.filter,
              labelOf: (status) => switch (status) {
                VerificationStatus.pending => l10n.adminVerifyTabPending,
                VerificationStatus.approved => l10n.adminVerifyTabApproved,
                VerificationStatus.rejected => l10n.adminVerifyTabRejected,
              },
              onSelected: (status) {
                _select(null);
                unawaited(cubit.filterChanged(status));
              },
            ),
            state: state,
            emptyMessage: state.filter == VerificationStatus.pending
                ? l10n.adminVerifyEmptyPending
                : l10n.adminVerifyEmpty,
            onRetry: cubit.load,
            rowBuilder: (item) => QueueTile(
              title: item.name,
              subtitle:
                  '${item.areaName} · '
                  '${adminAgeLabel(l10n, item.submittedAt, now: now)}',
              selected: item.verificationId == _selectedId,
              onTap: () => _select(item.verificationId),
            ),
            footer: PagerBar.of(
              state,
              summary: l10n.adminRowsOfTotal,
              onPage: cubit.goToPage,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: _selectedId == null
                ? Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: AdminEmptyView(l10n.adminVerifyPickOne),
                  )
                : VerificationReview(
                    key: ValueKey(_selectedId),
                    verificationId: _selectedId!,
                    onReviewed: _reviewed,
                  ),
          ),
        ],
      ),
    );
  }
}
