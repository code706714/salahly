import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/section_header.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/features/balance/presentation/cubit/balance_cubit.dart';
import 'package:salahly/features/balance/presentation/uses_left.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The balance: the uses left, the transfers and what moved the balance.
class BalancePage extends StatelessWidget {
  const BalancePage({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = BalanceCubit(
          balance: context.read(),
          session: context.read(),
          role: role,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BalanceView(role: role),
    );
  }
}

class BalanceView extends StatelessWidget {
  const BalanceView({required this.role, super.key});

  final UserRole role;

  Future<void> _buy(BuildContext context) async {
    final cubit = context.read<BalanceCubit>();
    await context.push<bool>(AppRoutes.buyUsesFor(role));
    if (!cubit.isClosed) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.watchHonorific();
    final cubit = context.read<BalanceCubit>();
    final state = context.watch<BalanceCubit>().state;
    return Scaffold(
      appBar: DetailHeader(title: l10n.balanceTitle),
      body: RefreshIndicator(
        onRefresh: cubit.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _UsesCard(role: role, onBuy: () => _buy(context)),
            const SizedBox(height: 20),
            if (state.status == BalanceStatus.loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.status == BalanceStatus.failed)
              _Failed(honorific: honorific, onRetry: cubit.load)
            else ...[
              SectionHeader(title: l10n.balanceTransfers),
              const SizedBox(height: 12),
              if (state.topups.isEmpty)
                _Empty(text: l10n.balanceTransfersEmpty(honorific))
              else
                for (final topup in state.topups) ...[
                  _TopupCard(topup: topup, role: role),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 12),
              SectionHeader(title: l10n.balanceLedger),
              const SizedBox(height: 12),
              if (state.ledger.isEmpty)
                _Empty(text: l10n.balanceLedgerEmpty)
              else
                _LedgerList(entries: state.ledger, role: role),
            ],
          ],
        ),
      ),
    );
  }
}

/// The uses left on the dark card, with the button to buy more.
class _UsesCard extends StatelessWidget {
  const _UsesCard({required this.role, required this.onBuy});

  final UserRole role;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final left = context.watchUsesLeft(role);
    final (title, count) = switch (role) {
      UserRole.consumer => (
        l10n.consumerAccountCreditsTitle,
        l10n.consumerAccountCredits(left),
      ),
      UserRole.technician => (
        l10n.balanceUsesTechnician,
        l10n.balanceTechnicianCredits(left),
      ),
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onInkMuted,
                  ),
                ),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: colors.background,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onBuy,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l10n.balanceBuy(context.watchHonorific())),
          ),
        ],
      ),
    );
  }
}

class _TopupCard extends StatelessWidget {
  const _TopupCard({required this.topup, required this.role});

  final Topup topup;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final name = switch (role) {
      UserRole.consumer => l10n.buyUsesPackConsumer(topup.uses),
      UserRole.technician => l10n.buyUsesPackTechnician(topup.uses),
    };
    final reason = topup.rejectReason;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l10n.pounds(formatPounds(topup.amountPiastres)),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${topupMethodLabel(l10n, topup.method)} · '
            '${weekdayDate(topup.createdAt)}',
            style: TextStyle(fontSize: 13, color: colors.inkMuted),
          ),
          const SizedBox(height: 8),
          StatusPill(
            label: topupStatusLabel(l10n, topup.status),
            tone: topupStatusTone(topup.status),
          ),
          if (topup.status == TopupStatus.rejected && reason != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.balanceRejectReason(reason),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.dangerDeep,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.entries, required this.role});

  final List<LedgerEntry> entries;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          for (final entry in entries) ...[
            if (entry != entries.first)
              Divider(height: 1, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ledgerReasonLabel(l10n, entry.reason, role: role),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          weekdayDate(entry.createdAt),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    entry.delta > 0 ? '+${entry.delta}' : '${entry.delta}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: entry.delta > 0 ? colors.success : colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          height: 1.6,
          color: context.appColors.inkMuted,
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.honorific, required this.onRetry});

  final String honorific;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Text(
          l10n.balanceLoadFailed(honorific),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
