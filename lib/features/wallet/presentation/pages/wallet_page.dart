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
import 'package:salahly/core/widgets/live_refresh.dart';
import 'package:salahly/core/widgets/section_header.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:salahly/features/wallet/presentation/wallet_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's wallet: the balance he can withdraw, what moved it and
/// where his withdrawals stand.
class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = WalletCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const WalletView(),
    );
  }
}

class WalletView extends StatelessWidget {
  const WalletView({super.key});

  Future<void> _withdraw(BuildContext context) async {
    final cubit = context.read<WalletCubit>();
    await context.push<bool>(AppRoutes.technicianWithdraw);
    if (!cubit.isClosed) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WalletCubit>();
    return Scaffold(
      appBar: DetailHeader(title: l10n.walletTitle),
      body: LiveRefresh(
        onChange: () => unawaited(cubit.load()),
        child: BlocBuilder<WalletCubit, WalletState>(
          builder: (context, state) {
            final wallet = state.wallet;
            if (state.status == WalletStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (wallet == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.walletUnavailable,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => unawaited(cubit.retry()),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _BalanceCard(
                    wallet: wallet,
                    onWithdraw: () => unawaited(_withdraw(context)),
                  ),
                  if (wallet.withdrawals.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    SectionHeader(title: l10n.walletWithdrawalsTitle),
                    const SizedBox(height: 12),
                    for (final withdrawal in wallet.withdrawals) ...[
                      _WithdrawalCard(withdrawal: withdrawal),
                      const SizedBox(height: 8),
                    ],
                  ],
                  const SizedBox(height: 12),
                  SectionHeader(title: l10n.walletHistoryTitle),
                  const SizedBox(height: 12),
                  if (wallet.entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      child: Text(
                        l10n.walletEmpty,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: context.appColors.inkMuted,
                        ),
                      ),
                    )
                  else
                    _EntryList(entries: wallet.entries),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The balance on the dark card, with the button to withdraw it.
class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.wallet, required this.onWithdraw});

  final Wallet wallet;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
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
                  l10n.walletBalanceLabel,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: colors.onInkMuted,
                  ),
                ),
                Text(
                  l10n.pounds(formatPounds(wallet.balancePiastres)),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                    color: colors.background,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: wallet.canWithdraw ? onWithdraw : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l10n.walletWithdrawAction),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCard extends StatelessWidget {
  const _WithdrawalCard({required this.withdrawal});

  final Withdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.walletWithdrawalLine(
              formatPounds(withdrawal.amountPiastres),
              withdrawal.account,
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            '${topupMethodLabel(l10n, withdrawal.method)} · '
            '${weekdayDate(withdrawal.createdAt)}',
            style: TextStyle(fontSize: 13, color: colors.inkMuted),
          ),
          const SizedBox(height: 8),
          StatusPill(
            label: withdrawalStatusLabel(l10n, withdrawal),
            tone: withdrawalStatusTone(withdrawal.status),
          ),
        ],
      ),
    );
  }
}

class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries});

  final List<WalletEntry> entries;

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
                          walletEntryLabel(l10n, entry),
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
                    '${entry.amountPiastres > 0 ? '+' : '-'}'
                    '${formatPounds(entry.amountPiastres.abs())}',
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: entry.amountPiastres > 0
                          ? colors.success
                          : colors.ink,
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
