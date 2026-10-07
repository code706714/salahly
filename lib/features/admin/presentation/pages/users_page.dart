import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/users_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/area_filter.dart';
import 'package:salahly/features/admin/presentation/widgets/pager_bar.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technicians and the customers, with the ability to suspend an
/// account and to restore it.
class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = UsersCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(create: (context) => UserActionsCubit(context.read())),
      ],
      child: const _UsersView(),
    );
  }
}

class _UsersView extends StatelessWidget {
  const _UsersView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<UsersCubit>().state;
    final cubit = context.read<UsersCubit>();
    final filter = state.filter;

    return AdminActionListener<UserActionsCubit>(
      onChanged: () {
        unawaited(cubit.reload());
        unawaited(context.read<OverviewCubit>().refresh());
      },
      child: AdminPage(
        title: l10n.adminUsersTitle,
        trailing: AdminTabs<UserRole>(
          values: UserRole.values,
          selected: filter.role,
          labelOf: (role) => switch (role) {
            UserRole.technician => l10n.adminUsersTabTechnicians,
            UserRole.consumer => l10n.adminUsersTabConsumers,
          },
          onSelected: (role) => cubit.filterChanged(filter.withRole(role)),
        ),
        child: Column(
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
                    // A new field per tab, so a search typed for one list
                    // is not left in the box of the other.
                    key: ValueKey(filter.role),
                    hint: l10n.adminUsersSearchHint,
                    initialText: filter.search,
                    onChanged: (text) => cubit.filterChanged(
                      filter.copyWith(search: text.trim()),
                    ),
                  ),
                ),
                AreaFilter(
                  areaId: filter.areaId,
                  onChanged: (areaId) => cubit.filterChanged(
                    filter.copyWith(areaId: () => areaId),
                  ),
                ),
                AdminDropdown<AccountStatus>(
                  label: l10n.adminStatusFilter,
                  value: filter.status,
                  values: accountStatusesOf(filter.role),
                  labelOf: (status) => accountStatusLabel(l10n, status),
                  allLabel: l10n.adminAllStatuses,
                  onChanged: (status) => cubit.filterChanged(
                    filter.copyWith(status: () => status),
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
                  _Table(state: state, onRetry: cubit.load),
                  const SizedBox(height: 12),
                  PagerBar.of(
                    state,
                    summary: l10n.adminUsersTotal,
                    onPage: cubit.goToPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.state, required this.onRetry});

  final PagedState<AdminUser, UserFilter> state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final now = context.watch<ClockCubit>().state;
    final isTechnician = state.filter.role == UserRole.technician;

    if (state.failure case final failure? when state.items.isEmpty) {
      return AdminFailureView(failure: failure, onRetry: onRetry);
    }
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.isEmpty) return AdminEmptyView(l10n.adminUsersEmpty);

    return Opacity(
      opacity: state.isLoading ? 0.6 : 1,
      child: AdminTable(
        headers: [
          if (isTechnician)
            l10n.adminUsersColTechnician
          else
            l10n.adminUsersColCustomer,
          l10n.adminUsersColArea,
          l10n.adminUsersColStatus,
          if (isTechnician) ...[
            l10n.adminUsersColRating,
            l10n.adminUsersColJobs,
          ] else ...[
            l10n.adminUsersColRequests,
            l10n.adminUsersColComplaints,
          ],
          l10n.adminUsersColBalance,
          if (isTechnician)
            l10n.adminUsersColLastSeen
          else
            l10n.adminUsersColLastRequest,
          '',
        ],
        flexes: const [4, 3, 3, 2, 2, 2, 3, 2],
        rows: [
          for (final user in state.items)
            AdminTableRow(
              cells: [
                _Identity(user),
                Text(user.areaName),
                _Status(user),
                ...switch (user) {
                  AdminTechnician() => [
                    Text(
                      user.rating == null
                          ? l10n.adminUsersNoRating
                          : '${user.rating!.toStringAsFixed(1)} '
                                '(${user.reviewCount})',
                    ),
                    Text('${user.platformJobs}'),
                  ],
                  AdminConsumer() => [
                    Text('${user.requestsCount}'),
                    Text(
                      '${user.complaintsCount}',
                      style: user.complaintsCount > 0
                          ? TextStyle(
                              color: context.appColors.dangerDeep,
                              fontWeight: FontWeight.w700,
                            )
                          : null,
                    ),
                  ],
                },
                Text('${user.balance}'),
                Text(switch (user) {
                  AdminTechnician(:final lastSignInAt) ||
                  AdminConsumer(lastRequestAt: final lastSignInAt) =>
                    lastSignInAt == null
                        ? l10n.adminNever
                        : adminAgeLabel(l10n, lastSignInAt, now: now),
                }),
                _Action(user),
              ],
            ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity(this.user);

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            adminPhoneLabel(user.phone),
            style: TextStyle(fontSize: 13, color: colors.inkMuted),
          ),
        ),
        if (user.suspensionReason case final reason? when user.isSuspended)
          Text(
            l10n.adminUsersReasonLine(reason),
            style: TextStyle(fontSize: 12, color: colors.dangerDeep),
          ),
      ],
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.user);

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StatusPill(
          label: accountStatusLabel(l10n, user.status),
          tone: accountStatusTone(user.status),
        ),
        if (user.pendingTopup) ...[
          const SizedBox(height: 4),
          StatusPill(
            label: l10n.adminUsersPendingTransfer,
            tone: PillTone.waiting,
          ),
        ],
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action(this.user);

  final AdminUser user;

  Future<void> _suspend(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<UserActionsCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminSuspendTitle(user.name),
      body: l10n.adminSuspendBody,
      confirmLabel: l10n.adminSuspendConfirm,
      fieldLabel: l10n.adminReasonLabel,
    );
    if (reason != null) await cubit.suspend(user.id, reason);
  }

  Future<void> _restore(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<UserActionsCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminUsersRestoreTitle(user.name),
      body: l10n.adminUsersRestoreBody,
      confirmLabel: l10n.adminUsersRestoreConfirm,
    );
    if (confirmed) await cubit.restore(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isBusy = context.select<UserActionsCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    return user.isSuspended
        ? OutlinedButton(
            onPressed: isBusy ? null : () => _restore(context, l10n),
            child: Text(l10n.adminUsersRestore),
          )
        : TextButton(
            onPressed: isBusy ? null : () => _suspend(context, l10n),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.adminUsersSuspend),
          );
  }
}
