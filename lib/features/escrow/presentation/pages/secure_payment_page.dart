import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/presentation/widgets/step_label.dart';
import 'package:salahly/features/balance/presentation/widgets/transfer_account_card.dart';
import 'package:salahly/features/balance/presentation/widgets/transfer_screenshot_field.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';
import 'package:salahly/features/escrow/presentation/escrow_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Paying a request's price to Salahly. Pops `true` once the transfer is
/// sent to be checked.
class SecurePaymentPage extends StatelessWidget {
  const SecurePaymentPage({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SecurePaymentCubit(
          escrow: context.read(),
          balance: context.read(),
          photos: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const SecurePaymentView(),
    );
  }
}

class SecurePaymentView extends StatefulWidget {
  const SecurePaymentView({super.key});

  @override
  State<SecurePaymentView> createState() => _SecurePaymentViewState();
}

class _SecurePaymentViewState extends State<SecurePaymentView> {
  final _sender = TextEditingController();
  final _senderFocus = FocusNode();

  /// Whether the sender field was left once, so a half-typed number isn't
  /// called wrong while it is typed.
  bool _senderTouched = false;

  @override
  void initState() {
    super.initState();
    _senderFocus.addListener(() {
      if (!_senderFocus.hasFocus && _sender.text.isNotEmpty) {
        setState(() => _senderTouched = true);
      }
    });
  }

  @override
  void dispose() {
    _sender.dispose();
    _senderFocus.dispose();
    super.dispose();
  }

  void _onState(BuildContext context, SecurePaymentState state) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == SecurePaymentStatus.submitted) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.escrowSecureSent)));
      Navigator.of(context).pop(true);
    } else if (state.failure != null &&
        state.status == SecurePaymentStatus.editing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              escrowFailureMessage(
                l10n,
                state.failure!,
                honorific: context.readHonorific(),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final honorific = context.watchHonorific();
    final cubit = context.read<SecurePaymentCubit>();
    return BlocConsumer<SecurePaymentCubit, SecurePaymentState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: _onState,
      builder: (context, state) {
        final loaded = switch (state.status) {
          SecurePaymentStatus.loading || SecurePaymentStatus.failed => false,
          _ => true,
        };
        return PopScope(
          canPop: state.status != SecurePaymentStatus.submitting,
          child: Scaffold(
            appBar: DetailHeader(title: l10n.escrowSecureTitle(honorific)),
            body: switch (state.status) {
              SecurePaymentStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              SecurePaymentStatus.failed => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l10n.escrowSecureUnavailable(honorific),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.6),
                  ),
                ),
              ),
              _ => _Steps(
                state: state,
                honorific: honorific,
                sender: _sender,
                senderFocus: _senderFocus,
                senderTouched: _senderTouched,
              ),
            },
            bottomNavigationBar: loaded
                ? BottomActionBar(
                    child: BusyFilledButton(
                      label: l10n.buyUsesSubmit(honorific),
                      isBusy: state.status == SecurePaymentStatus.submitting,
                      onPressed: state.canSubmit ? cubit.submit : null,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.state,
    required this.honorific,
    required this.sender,
    required this.senderFocus,
    required this.senderTouched,
  });

  final SecurePaymentState state;
  final String honorific;
  final TextEditingController sender;
  final FocusNode senderFocus;
  final bool senderTouched;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SecurePaymentCubit>();
    final account = state.account;
    final method = state.method;
    final methods = [
      for (final method in TopupMethod.values)
        if (state.accounts.any((account) => account.method == method)) method,
    ];
    final wallet = method == TopupMethod.wallet;
    final senderWrong =
        senderTouched && sender.text.isNotEmpty && state.validSender == null;
    final amount = formatPounds(state.amountPiastres);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Intro(text: l10n.escrowSecureIntro(honorific, amount)),
        const SizedBox(height: 16),
        StepLabel(
          number: 1,
          label: l10n.buyUsesStepTransfer(honorific, amount),
        ),
        const SizedBox(height: 8),
        SegmentedTabs(
          labels: [
            for (final method in methods)
              switch (method) {
                TopupMethod.instapay => l10n.buyUsesMethodInstapay,
                TopupMethod.wallet => l10n.buyUsesMethodWallet,
              },
          ],
          selected: methods.indexOf(method!),
          onSelected: (index) => cubit.pickMethod(methods[index]),
        ),
        if (account != null) ...[
          const SizedBox(height: 8),
          TransferAccountCard(account: account, honorific: honorific),
        ],
        const SizedBox(height: 16),
        StepLabel(number: 2, label: l10n.buyUsesStepSender(honorific)),
        const SizedBox(height: 8),
        TextField(
          controller: sender,
          focusNode: senderFocus,
          onChanged: cubit.setSender,
          textDirection: TextDirection.ltr,
          keyboardType: wallet ? TextInputType.phone : TextInputType.text,
          inputFormatters: wallet
              ? [
                  ...digitInputFormatters(maxLength: 20),
                  FilteringTextInputFormatter.deny(' '),
                ]
              : [LengthLimitingTextInputFormatter(64)],
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            errorText: senderWrong
                ? (wallet
                      ? l10n.buyUsesSenderInvalidWallet(honorific)
                      : l10n.buyUsesSenderInvalidInstapay(honorific))
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
        ),
        const SizedBox(height: 16),
        StepLabel(number: 3, label: l10n.buyUsesStepScreenshot(honorific)),
        const SizedBox(height: 8),
        TransferScreenshotField(
          photoPicker: context.read<PhotoPicker>(),
          honorific: honorific,
          path: state.screenshot,
          onPicked: cubit.attachScreenshot,
        ),
      ],
    );
  }
}

/// The dark card on top: what the guarantee does.
class _Intro extends StatelessWidget {
  const _Intro({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, height: 1.6, color: colors.onInkMuted),
      ),
    );
  }
}
