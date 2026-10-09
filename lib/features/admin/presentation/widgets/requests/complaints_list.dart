import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/presentation/cubit/complaints_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/features/admin/presentation/widgets/requests/complaint_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The customers' complaints about technicians, one card each, the open
/// ones first by default.
class ComplaintsList extends StatelessWidget {
  const ComplaintsList({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ComplaintsCubit>().state;
    final cubit = context.read<ComplaintsCubit>();

    final Widget content;
    if (state.failure case final failure? when state.items.isEmpty) {
      content = AdminFailureView(failure: failure, onRetry: cubit.load);
    } else if (state.isLoading && state.items.isEmpty) {
      content = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.isEmpty) {
      content = AdminEmptyView(
        state.filter == ComplaintFilter.open
            ? l10n.adminComplaintsEmptyOpen
            : l10n.adminComplaintsEmpty,
      );
    } else {
      content = Opacity(
        opacity: state.isLoading ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final complaint in state.items) ...[
              ComplaintCard(key: ValueKey(complaint.id), complaint: complaint),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AdminTabs<ComplaintFilter>(
            values: ComplaintFilter.values,
            selected: state.filter,
            labelOf: (filter) => switch (filter) {
              ComplaintFilter.open => l10n.adminComplaintsTabOpen,
              ComplaintFilter.resolved => l10n.adminComplaintsTabResolved,
              ComplaintFilter.all => l10n.adminComplaintsTabAll,
            },
            onSelected: cubit.filterChanged,
          ),
        ),
        const SizedBox(height: 16),
        content,
        PagerBar.of(
          state,
          summary: l10n.adminRowsOfTotal,
          onPage: cubit.goToPage,
        ),
      ],
    );
  }
}
