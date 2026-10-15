import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/failures/wallet_failures.dart';
import 'package:salahly/features/wallet/presentation/cubit/withdraw_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks for money out of the wallet, to a Vodafone Cash number or an
/// InstaPay address the technician types.
class WithdrawPage extends StatelessWidget {
  const WithdrawPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = WithdrawCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const WithdrawView(),
    );
  }
}

class WithdrawView extends StatefulWidget {
  const WithdrawView({super.key});

  @override
  State<WithdrawView> createState() => _WithdrawViewState();
}

class _WithdrawViewState extends State<WithdrawView> {
  final _amount = TextEditingController();
  final _account = TextEditingController();
  final _holder = TextEditingController();

  /// The last number used is put in the fields once, when it arrives.
  bool _filled = false;

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, WithdrawState state) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_filled && state.status == WithdrawStatus.editing) {
      _filled = true;
      _account.text = state.account;
      _holder.text = state.holder;
    }
    if (state.status == WithdrawStatus.sent) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.withdrawSent)));
      Navigator.of(context).pop(true);
    } else if (state.failure != null &&
        state.status == WithdrawStatus.editing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_failureMessage(l10n, state.failure!))),
        );
    }
  }

  String _failureMessage(AppLocalizations l10n, Failure failure) =>
      switch (failure) {
        AmountTooSmallFailure() => l10n.withdrawAmountTooSmall,
        InsufficientBalanceFailure() => l10n.withdrawInsufficient,
        InvalidHolderFailure() => l10n.withdrawInvalidHolder,
        InvalidWithdrawalAccountFailure() => l10n.withdrawInvalidAccount,
        _ => commonFailureMessage(l10n, failure),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<WithdrawCubit>();
    return BlocConsumer<WithdrawCubit, WithdrawState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: _onState,
      builder: (context, state) {
        final editable = switch (state.status) {
          WithdrawStatus.loading || WithdrawStatus.failed => false,
          _ => true,
        };
        final wallet = state.method == TopupMethod.wallet;
        return Scaffold(
          appBar: DetailHeader(title: l10n.withdrawTitle),
          body: switch (state.status) {
            WithdrawStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            WithdrawStatus.failed => Center(
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
                      onPressed: cubit.load,
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
            _ => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.withdrawIntro,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amount,
                  onChanged: cubit.setAmount,
                  textDirection: TextDirection.ltr,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitInputFormatters(maxLength: 7),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.withdrawAmount,
                    helperText:
                        '${l10n.withdrawAvailable(
                          formatPounds(state.balancePiastres),
                        )} · ${l10n.withdrawMinimum(
                          formatPounds(state.minPiastres),
                        )}',
                  ),
                ),
                const SizedBox(height: 16),
                SegmentedTabs(
                  labels: [
                    l10n.buyUsesMethodInstapay,
                    l10n.buyUsesMethodWallet,
                  ],
                  selected: TopupMethod.values.indexOf(state.method),
                  onSelected: (index) =>
                      cubit.pickMethod(TopupMethod.values[index]),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _account,
                  onChanged: cubit.setAccount,
                  textDirection: TextDirection.ltr,
                  keyboardType: wallet
                      ? TextInputType.phone
                      : TextInputType.text,
                  inputFormatters: wallet
                      ? [
                          ...digitInputFormatters(maxLength: 20),
                          FilteringTextInputFormatter.deny(' '),
                        ]
                      : [LengthLimitingTextInputFormatter(64)],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(labelText: l10n.withdrawNumber),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _holder,
                  onChanged: cubit.setHolder,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(labelText: l10n.withdrawHolder),
                ),
              ],
            ),
          },
          bottomNavigationBar: editable
              ? BottomActionBar(
                  child: BusyFilledButton(
                    label: l10n.withdrawSend,
                    isBusy: state.status == WithdrawStatus.sending,
                    onPressed: state.canSend ? cubit.send : null,
                  ),
                )
              : null,
        );
      },
    );
  }
}
