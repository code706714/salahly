import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/activity_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_table.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The money of today, this week or this month, and what every technician
/// who worked in that time did.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ActivityCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _ActivityView(),
    );
  }
}

class _ActivityView extends StatelessWidget {
  const _ActivityView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<ActivityCubit>().state;
    final cubit = context.read<ActivityCubit>();
    final money = state.money;
    final report = state.report;

    return AdminPage(
      title: l10n.adminActivityTitle,
      subtitle: l10n.adminActivitySubtitle,
      trailing: AdminTabs<OverviewPeriod>(
        values: OverviewPeriod.values,
        selected: state.period,
        labelOf: (period) => overviewPeriodLabel(l10n, period),
        onSelected: cubit.selectPeriod,
      ),
      child: money == null || report == null
          ? SizedBox(
              height: 320,
              child: state.failure != null
                  ? AdminFailureView(
                      failure: state.failure!,
                      onRetry: cubit.load,
                    )
                  : const Center(child: CircularProgressIndicator()),
            )
          : Opacity(
              opacity: state.isLoading ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MoneySection(money: money),
                  const SizedBox(height: 24),
                  _TechniciansSection(report: report),
                ],
              ),
            ),
    );
  }
}

String _pounds(AppLocalizations l10n, int piastres) =>
    l10n.pounds(formatPounds(piastres));

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.titleLarge);
}

class _MoneySection extends StatelessWidget {
  const _MoneySection({required this.money});

  final MoneySummary money;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final withdrawals = money.withdrawals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.adminActivityMoneyTitle),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Stat(
                  title: l10n.adminActivityEarned,
                  value: _pounds(l10n, money.earnedPiastres),
                  note: l10n.adminActivityEarnedNote,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                  title: l10n.adminActivityPaidIn,
                  value: _pounds(l10n, money.paidInPiastres),
                  note: l10n.adminActivityPaidInNote(
                    money.paidInCount,
                    _pounds(l10n, money.escrowPaidInPiastres),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                  title: l10n.adminActivityReleased,
                  value: _pounds(l10n, money.releasedToWalletsPiastres),
                  note: l10n.adminActivityReleasedNote,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _Stat(
                  title: l10n.adminActivityWithdrawals,
                  value: _pounds(l10n, withdrawals.paidPiastres),
                  note: [
                    l10n.adminActivityWithdrawalsRequested(
                      _pounds(l10n, withdrawals.requestedPiastres),
                      withdrawals.requestedCount,
                    ),
                    l10n.adminActivityWithdrawalsPaid(
                      _pounds(l10n, withdrawals.paidPiastres),
                      withdrawals.paidCount,
                    ),
                    if (withdrawals.waitingCount > 0)
                      l10n.adminActivityWithdrawalsWaiting(
                        _pounds(l10n, withdrawals.waitingPiastres),
                        withdrawals.waitingCount,
                      ),
                  ].join('\n'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: money.transactions.isEmpty
              ? AdminEmptyView(l10n.adminActivityTransactionsEmpty)
              : AdminTable(
                  headers: [
                    l10n.adminActivityColWhen,
                    l10n.adminActivityColKind,
                    l10n.adminActivityColPerson,
                    l10n.adminActivityColAmount,
                  ],
                  flexes: const [4, 4, 4, 3],
                  rows: [
                    for (final transaction in money.transactions)
                      AdminTableRow(
                        cells: [
                          Text(adminDateTimeLabel(transaction.at)),
                          Text(_kindLabel(l10n, transaction.kind)),
                          Text(
                            transaction.personName ??
                                l10n.adminActivityUnknownPerson,
                          ),
                          Text(
                            _pounds(l10n, transaction.amountPiastres),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  String _kindLabel(AppLocalizations l10n, MoneyTransactionKind kind) =>
      switch (kind) {
        MoneyTransactionKind.packPayment => l10n.adminActivityKindPack,
        MoneyTransactionKind.escrowPayment => l10n.adminActivityKindEscrow,
        MoneyTransactionKind.withdrawalRequested =>
          l10n.adminActivityKindWithdrawalRequested,
        MoneyTransactionKind.withdrawalPaid =>
          l10n.adminActivityKindWithdrawalPaid,
        MoneyTransactionKind.withdrawalRejected =>
          l10n.adminActivityKindWithdrawalRejected,
      };
}

class _Stat extends StatelessWidget {
  const _Stat({required this.title, required this.value, required this.note});

  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _TechniciansSection extends StatelessWidget {
  const _TechniciansSection({required this.report});

  final ActivityReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading(l10n.adminActivityTechniciansTitle),
        const SizedBox(height: 4),
        Text(
          l10n.adminActivityTechniciansSummary(
            report.techniciansActive,
            report.jobsCount,
            report.finishedCount,
            _pounds(l10n, report.billedPiastres),
          ),
          style: TextStyle(color: colors.inkMuted),
        ),
        const SizedBox(height: 12),
        if (report.technicians.isEmpty)
          AppCard(child: AdminEmptyView(l10n.adminActivityTechniciansEmpty))
        else
          for (final technician in report.technicians)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TechnicianCard(technician: technician),
            ),
      ],
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.technician});

  final TechnicianActivity technician;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final phone = technician.phone;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            [
              technician.name ?? l10n.adminActivityUnknownPerson,
              ?(phone == null ? null : adminPhoneLabel(phone)),
            ].join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            l10n.adminActivityTechnicianStats(
              technician.jobsCount,
              technician.finishedCount,
              technician.customersCount,
              _pounds(l10n, technician.billedPiastres),
              _pounds(l10n, technician.paidPiastres),
            ),
            style: TextStyle(color: colors.inkMuted),
          ),
          children: [
            AdminTable(
              headers: [
                l10n.adminActivityColWhen,
                l10n.adminActivityColCustomer,
                l10n.adminActivityColStatus,
                l10n.adminActivityColSource,
                l10n.adminActivityColBilled,
                l10n.adminActivityColPaid,
              ],
              flexes: const [4, 4, 3, 3, 3, 3],
              rows: [
                for (final job in technician.jobs)
                  AdminTableRow(
                    cells: [
                      Text(adminDateTimeLabel(job.at)),
                      Text(
                        job.customerName ?? l10n.adminActivityUnknownCustomer,
                      ),
                      Text(jobStatusLabel(l10n, job.status)),
                      Text(
                        job.isFromApp
                            ? l10n.adminActivityJobFromApp
                            : l10n.adminActivityJobOwn,
                      ),
                      Text(_pounds(l10n, job.totalPiastres)),
                      Text(_pounds(l10n, job.paidPiastres)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
