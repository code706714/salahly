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
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/presentation/buy_uses_failure_message.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';
import 'package:salahly/features/balance/presentation/uses_left.dart';
import 'package:salahly/features/balance/presentation/widgets/pack_tile.dart';
import 'package:salahly/features/balance/presentation/widgets/step_label.dart';
import 'package:salahly/features/balance/presentation/widgets/transfer_account_card.dart';
import 'package:salahly/features/balance/presentation/widgets/transfer_screenshot_field.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Buying uses by transfer. Pops `true` once the transfer is sent for
/// review.
class BuyUsesPage extends StatelessWidget {
  const BuyUsesPage({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = BuyUsesCubit(balance: context.read(), role: role);
        unawaited(cubit.load());
        return cubit;
      },
      child: BuyUsesView(role: role),
    );
  }
}

/// The steps: the pack, where to send the money, where it came from and
/// the screenshot.
class BuyUsesView extends StatefulWidget {
  const BuyUsesView({required this.role, super.key});

  final UserRole role;

  @override
  State<BuyUsesView> createState() => _BuyUsesViewState();
}

class _BuyUsesViewState extends State<BuyUsesView> {
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

  void _onState(BuildContext context, BuyUsesState state) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (state.status == BuyUsesStatus.submitted) {
      unawaited(context.read<SessionCubit>().refreshProfile());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.buyUsesSent)));
      Navigator.of(context).pop(true);
    } else if (state.failure != null && state.status == BuyUsesStatus.editing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              buyUsesFailureMessage(
                l10n,
                state.failure!,
                role: widget.role,
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
    final role = widget.role;
    final cubit = context.read<BuyUsesCubit>();
    final title = switch (role) {
      UserRole.consumer => l10n.buyUsesTitleConsumer(honorific),
      UserRole.technician => l10n.buyUsesTitleTechnician,
    };
    return BlocConsumer<BuyUsesCubit, BuyUsesState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: _onState,
      builder: (context, state) {
        final loaded = switch (state.status) {
          BuyUsesStatus.loading || BuyUsesStatus.failed => false,
          _ => true,
        };
        return Scaffold(
          appBar: DetailHeader(title: title),
          body: switch (state.status) {
            BuyUsesStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            BuyUsesStatus.failed => _Unavailable(
              honorific: honorific,
              onRetry: cubit.load,
            ),
            _ => _Steps(
              role: role,
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
                    isBusy: state.status == BuyUsesStatus.submitting,
                    onPressed: state.canSubmit ? cubit.submit : null,
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.honorific, required this.onRetry});

  final String honorific;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.buyUsesUnavailable(honorific),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({
    required this.role,
    required this.state,
    required this.honorific,
    required this.sender,
    required this.senderFocus,
    required this.senderTouched,
  });

  final UserRole role;
  final BuyUsesState state;
  final String honorific;
  final TextEditingController sender;
  final FocusNode senderFocus;
  final bool senderTouched;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<BuyUsesCubit>();
    final pack = state.pack;
    final account = state.account;
    final method = state.method;
    final methods = [
      for (final method in TopupMethod.values)
        if (state.accounts.any((account) => account.method == method)) method,
    ];
    final wallet = method == TopupMethod.wallet;
    final senderWrong =
        senderTouched && sender.text.isNotEmpty && state.validSender == null;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Intro(role: role, honorific: honorific),
        const SizedBox(height: 16),
        StepLabel(number: 1, label: l10n.buyUsesStepPack(honorific)),
        const SizedBox(height: 8),
        for (final option in state.packs) ...[
          if (option != state.packs.first) const SizedBox(height: 8),
          PackTile(
            pack: option,
            role: role,
            honorific: honorific,
            selected: option.id == state.packId,
            singlePricePiastres: state.singlePricePiastres,
            onTap: () => cubit.pickPack(option.id),
          ),
        ],
        const SizedBox(height: 16),
        StepLabel(
          number: 2,
          label: l10n.buyUsesStepTransfer(
            honorific,
            formatPounds(pack?.pricePiastres ?? 0),
          ),
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
        StepLabel(number: 3, label: l10n.buyUsesStepSender(honorific)),
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
        StepLabel(number: 4, label: l10n.buyUsesStepScreenshot(honorific)),
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

/// The dark card on top: where the person stands and why to buy.
class _Intro extends StatelessWidget {
  const _Intro({required this.role, required this.honorific});

  final UserRole role;
  final String honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final left = context.watchUsesLeft(role);
    final (title, body) = switch (role) {
      UserRole.consumer => (
        left > 0
            ? '${l10n.consumerHomeCreditsLead(honorific)} '
                  '${l10n.consumerHomeCreditsCount(left)}'
            : l10n.buyUsesConsumerIntroNone(honorific),
        l10n.buyUsesConsumerIntroBody(honorific),
      ),
      UserRole.technician => (
        left > 0
            ? l10n.todayRequestsCreditsLeft(left)
            : l10n.buyUsesTechnicianIntroNone,
        l10n.buyUsesTechnicianIntroBody(left),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.background,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: colors.onInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
