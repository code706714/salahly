import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';
import 'package:salahly/features/payments/presentation/cubit/payment_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Pays on the provider's page and waits for the server to confirm. Pops
/// `true` only once the server says the money arrived; leaving earlier is
/// fine, the payment still completes on the server.
class PaymentPage extends StatelessWidget {
  const PaymentPage({required this.checkout, super.key});

  final PaymentCheckout checkout;

  /// Opens the payment screen for [checkout]; true when it was paid.
  static Future<bool> open(
    BuildContext context,
    PaymentCheckout checkout,
  ) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentPage(checkout: checkout)),
    );
    return paid ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = PaymentCubit(
          payments: context.read<PaymentRepository>(),
          apps: context.read<ExternalApps>(),
          checkout: checkout,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: _PaymentView(amountPiastres: checkout.amountPiastres),
    );
  }
}

class _PaymentView extends StatefulWidget {
  const _PaymentView({required this.amountPiastres});

  final int amountPiastres;

  @override
  State<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<_PaymentView>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the payment page: ask the server right away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(context.read<PaymentCubit>().refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final cubit = context.read<PaymentCubit>();
    return BlocBuilder<PaymentCubit, PaymentState>(
      builder: (context, state) {
        final (icon, color, title, body) = switch (state.progress) {
          PaymentProgress.waiting => (
            Icons.hourglass_top_rounded,
            colors.inkMuted,
            l10n.paymentWaitingTitle,
            state.status == PaymentStatus.pending
                ? l10n.paymentWaitingBody
                : l10n.paymentOpenBody,
          ),
          PaymentProgress.paid => (
            Icons.check_circle_outline_rounded,
            colors.success,
            l10n.paymentPaidTitle,
            l10n.paymentPaidBody,
          ),
          PaymentProgress.notPaid => (
            Icons.error_outline_rounded,
            colors.danger,
            l10n.paymentFailedTitle,
            switch (state.status) {
              PaymentStatus.expired => l10n.paymentExpiredBody,
              PaymentStatus.refunded => l10n.paymentRefundedBody,
              _ => l10n.paymentFailedBody,
            },
          ),
        };
        final waiting = state.progress == PaymentProgress.waiting;
        return Scaffold(
          appBar: DetailHeader(title: l10n.paymentTitle),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  children: [
                    Icon(icon, size: 48, color: color),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.paymentAmount(formatPounds(widget.amountPiastres)),
                      style: TextStyle(color: colors.inkMuted, fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomActionBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (waiting) ...[
                  FilledButton(
                    onPressed: () => unawaited(cubit.open()),
                    child: Text(l10n.paymentOpenAgain(honorific)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(l10n.paymentLater),
                  ),
                ] else
                  FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(state.progress == PaymentProgress.paid),
                    child: Text(
                      state.progress == PaymentProgress.paid
                          ? l10n.paymentDone
                          : l10n.paymentBack,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
