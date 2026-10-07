import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/audit_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What the team did, newest first. The log can not be edited.
class AuditPage extends StatelessWidget {
  const AuditPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AuditCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _AuditView(),
    );
  }
}

class _AuditView extends StatelessWidget {
  const _AuditView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<AuditCubit>().state;
    final cubit = context.read<AuditCubit>();
    final filter = state.filter;

    final Widget table;
    if (state.failure case final failure? when state.items.isEmpty) {
      table = AdminFailureView(failure: failure, onRetry: cubit.load);
    } else if (state.isLoading && state.items.isEmpty) {
      table = const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (state.isEmpty) {
      table = AdminEmptyView(l10n.adminAuditEmpty);
    } else {
      table = Opacity(
        opacity: state.isLoading ? 0.6 : 1,
        child: AdminTable(
          headers: [
            l10n.adminAuditColWhen,
            l10n.adminAuditColAdmin,
            l10n.adminAuditColAction,
            l10n.adminAuditColTarget,
            l10n.adminAuditColDetails,
          ],
          flexes: const [4, 3, 3, 4, 5],
          rows: [
            for (final entry in state.items)
              AdminTableRow(
                cells: [
                  Text(adminDateTimeLabel(entry.createdAt)),
                  Text(entry.adminName ?? l10n.adminAuditUnknownAdmin),
                  Text(
                    auditActionLabel(l10n, entry.action),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  _Target(entry),
                  _Details(entry.details),
                ],
              ),
          ],
        ),
      );
    }

    return AdminPage(
      title: l10n.adminAuditTitle,
      subtitle: l10n.adminAuditSubtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminDropdown<String>(
                label: l10n.adminAuditActionFilter,
                value: filter.action,
                values: auditActions,
                labelOf: (action) => auditActionLabel(l10n, action),
                allLabel: l10n.adminAuditAllActions,
                onChanged: (action) => cubit.filterChanged(
                  filter.copyWith(action: () => action),
                ),
              ),
              SizedBox(
                width: 340,
                child: AdminSearchField(
                  hint: l10n.adminAuditTargetHint,
                  initialText: filter.targetId,
                  onChanged: (text) => cubit.filterChanged(
                    filter.copyWith(targetId: text.trim()),
                  ),
                ),
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
                  summary: l10n.adminRowsOfTotal,
                  onPage: cubit.goToPage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Target extends StatelessWidget {
  const _Target(this.entry);

  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final id = entry.targetId;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        id == null ? entry.targetType : '${entry.targetType} · $id',
        style: TextStyle(fontSize: 12, color: context.appColors.inkMuted),
      ),
    );
  }
}

/// What an action recorded, such as the reason typed, as plain text.
class _Details extends StatelessWidget {
  const _Details(this.details);

  final Map<String, Object?> details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = details.isEmpty
        ? l10n.adminNone
        : details.entries
              .where((entry) => entry.value != null)
              .map((entry) => '${entry.key}: ${entry.value}')
              .join('، ');
    return Text(text, maxLines: 4, overflow: TextOverflow.ellipsis);
  }
}
