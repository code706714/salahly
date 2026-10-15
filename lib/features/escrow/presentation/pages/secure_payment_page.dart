import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';
import 'package:salahly/features/escrow/presentation/escrow_failure_message.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';
import 'package:salahly/features/payments/presentation/pages/payment_page.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Paying a request's price to Salahly online. Pops `true` once the server
/// confirmed the payment.
class SecurePaymentPage extends StatelessWidget {
  const SecurePaymentPage({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = SecurePaymentCubit(
          escrow: context.read(),
          payments: context.read<PaymentRepository>(),
          requestId: requestId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const SecurePaymentView(),
    );
  }
}

class SecurePaymentView extends StatelessWidget {
  const SecurePaymentView({super.key});

  Future<void> _onState(BuildContext context, SecurePaymentState state) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<SecurePaymentCubit>();
    final checkout = state.checkout;
    if (state.status == SecurePaymentStatus.paying && checkout != null) {
      final paid = await PaymentPage.open(context, checkout);
      cubit.paymentClosed();
      if (paid && context.mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.escrowSecurePaid)));
        Navigator.of(context).pop(true);
      }
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
      listener: (context, state) => unawaited(_onState(context, state)),
      builder: (context, state) {
        final loaded = switch (state.status) {
          SecurePaymentStatus.loading || SecurePaymentStatus.failed => false,
          _ => true,
        };
        final amount = formatPounds(state.amountPiastres);
        return PopScope(
          canPop: state.status != SecurePaymentStatus.starting,
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
              _ => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Intro(text: l10n.escrowSecureIntro(honorific, amount)),
                ],
              ),
            },
            bottomNavigationBar: loaded
                ? BottomActionBar(
                    child: BusyFilledButton(
                      label: l10n.buyUsesPay(honorific, amount),
                      isBusy: state.status == SecurePaymentStatus.starting,
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
