import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/balance/presentation/buy_uses_failure_message.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';
import 'package:salahly/features/balance/presentation/uses_left.dart';
import 'package:salahly/features/balance/presentation/widgets/pack_tile.dart';
import 'package:salahly/features/balance/presentation/widgets/step_label.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';
import 'package:salahly/features/payments/presentation/pages/payment_page.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Buying uses online. Pops `true` once the server confirmed the payment.
class BuyUsesPage extends StatelessWidget {
  const BuyUsesPage({required this.role, super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = BuyUsesCubit(
          balance: context.read(),
          payments: context.read<PaymentRepository>(),
          role: role,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: BuyUsesView(role: role),
    );
  }
}

/// The pack to buy and the button that pays for it.
class BuyUsesView extends StatelessWidget {
  const BuyUsesView({required this.role, super.key});

  final UserRole role;

  Future<void> _onState(BuildContext context, BuyUsesState state) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<BuyUsesCubit>();
    final checkout = state.checkout;
    if (state.status == BuyUsesStatus.paying && checkout != null) {
      final paid = await PaymentPage.open(context, checkout);
      cubit.paymentClosed();
      if (paid && context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.buyUsesPaid)));
        Navigator.of(context).pop(true);
      }
    } else if (state.failure != null && state.status == BuyUsesStatus.editing) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              buyUsesFailureMessage(
                l10n,
                state.failure!,
                role: role,
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
    final cubit = context.read<BuyUsesCubit>();
    final title = switch (role) {
      UserRole.consumer => l10n.buyUsesTitleConsumer(honorific),
      UserRole.technician => l10n.buyUsesTitleTechnician,
    };
    return BlocConsumer<BuyUsesCubit, BuyUsesState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.failure != current.failure,
      listener: (context, state) => unawaited(_onState(context, state)),
      builder: (context, state) {
        final loaded = switch (state.status) {
          BuyUsesStatus.loading || BuyUsesStatus.failed => false,
          _ => true,
        };
        return PopScope(
          canPop: state.status != BuyUsesStatus.starting,
          child: Scaffold(
            appBar: DetailHeader(title: title),
            body: switch (state.status) {
              BuyUsesStatus.loading => const Center(
                child: CircularProgressIndicator(),
              ),
              BuyUsesStatus.failed => _Unavailable(
                honorific: honorific,
                onRetry: cubit.load,
              ),
              _ => _Steps(role: role, state: state, honorific: honorific),
            },
            bottomNavigationBar: loaded
                ? BottomActionBar(
                    child: BusyFilledButton(
                      label: l10n.buyUsesPay(
                        honorific,
                        formatPounds(state.pack?.pricePiastres ?? 0),
                      ),
                      isBusy: state.status == BuyUsesStatus.starting,
                      onPressed: state.canPay ? cubit.pay : null,
                    ),
                  )
                : null,
          ),
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
  });

  final UserRole role;
  final BuyUsesState state;
  final String honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<BuyUsesCubit>();
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
        Text(
          l10n.buyUsesPayHint(honorific),
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: context.appColors.inkMuted,
          ),
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
