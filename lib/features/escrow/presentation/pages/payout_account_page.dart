import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/payout_account_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where Salahly pays the technician for guaranteed jobs.
class PayoutAccountPage extends StatelessWidget {
  const PayoutAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = PayoutAccountCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const PayoutAccountView(),
    );
  }
}

class PayoutAccountView extends StatefulWidget {
  const PayoutAccountView({super.key});

  @override
  State<PayoutAccountView> createState() => _PayoutAccountViewState();
}

class _PayoutAccountViewState extends State<PayoutAccountView> {
  final _account = TextEditingController();
  final _holder = TextEditingController();

  /// The saved values are put in the fields once, when they arrive.
  bool _filled = false;

  @override
  void dispose() {
    _account.dispose();
    _holder.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, PayoutAccountState state) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!_filled && state.status == PayoutAccountStatus.editing) {
      _filled = true;
      _account.text = state.account;
      _holder.text = state.holder;
    }
    if (state.status == PayoutAccountStatus.saved) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.payoutAccountSaved)));
      Navigator.of(context).pop();
    } else if (state.failure != null &&
        state.status == PayoutAccountStatus.editing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(_failureMessage(l10n, state.failure!))),
        );
    }
  }

  String _failureMessage(AppLocalizations l10n, Failure failure) =>
      switch (failure) {
        InvalidHolderFailure() => l10n.payoutAccountInvalidHolder,
        InvalidPayoutAccountFailure() => l10n.payoutAccountInvalidAccount,
        _ => commonFailureMessage(l10n, failure),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<PayoutAccountCubit>();
    return BlocConsumer<PayoutAccountCubit, PayoutAccountState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: _onState,
      builder: (context, state) {
        final editable = switch (state.status) {
          PayoutAccountStatus.loading || PayoutAccountStatus.failed => false,
          _ => true,
        };
        final wallet = state.method == TopupMethod.wallet;
        return Scaffold(
          appBar: DetailHeader(title: l10n.payoutAccountTitle),
          body: switch (state.status) {
            PayoutAccountStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            PayoutAccountStatus.failed => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.payoutAccountUnavailable,
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
                  l10n.payoutAccountIntro,
                  style: const TextStyle(fontSize: 15, height: 1.6),
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
                  decoration: InputDecoration(
                    labelText: l10n.payoutAccountNumber,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _holder,
                  onChanged: cubit.setHolder,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    labelText: l10n.payoutAccountHolder,
                  ),
                ),
              ],
            ),
          },
          bottomNavigationBar: editable
              ? BottomActionBar(
                  child: BusyFilledButton(
                    label: l10n.payoutAccountSave,
                    isBusy: state.status == PayoutAccountStatus.saving,
                    onPressed: state.canSave ? cubit.save : null,
                  ),
                )
              : null,
        );
      },
    );
  }
}
