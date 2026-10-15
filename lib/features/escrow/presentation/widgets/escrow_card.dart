import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/live_refresh.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/presentation/cubit/escrow_cubit.dart';
import 'package:salahly/features/escrow/presentation/escrow_failure_message.dart';
import 'package:salahly/features/escrow/presentation/widgets/dispute_dialog.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumer's money guarantee on a request: the offer to pay in before
/// the work, where the payment stands, and her answer once the work is
/// done. Shows nothing while there is nothing to say.
class EscrowCard extends StatelessWidget {
  const EscrowCard({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = EscrowCubit(
          escrow: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: _EscrowView(requestId: requestId),
    );
  }
}

class _EscrowView extends StatelessWidget {
  const _EscrowView({required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EscrowCubit>();
    return LiveRefresh(
      onChange: () => unawaited(cubit.load()),
      child: BlocConsumer<EscrowCubit, EscrowState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                escrowFailureMessage(
                  AppLocalizations.of(context),
                  state.failure!,
                  honorific: context.readHonorific(),
                ),
              ),
            ),
          ),
        builder: (context, state) {
          final info = state.info;
          if (info == null || !info.isRelevant) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _Body(
              info: info,
              busy: state.busy,
              requestId: requestId,
            ),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.info,
    required this.busy,
    required this.requestId,
  });

  final EscrowInfo info;
  final bool busy;
  final String requestId;

  Future<void> _secure(BuildContext context) async {
    final cubit = context.read<EscrowCubit>();
    await context.push<bool>(AppRoutes.securePayment(requestId));
    await cubit.load();
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<EscrowCubit>();
    final amount = formatPounds(info.amountPiastres);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.escrowConfirmQuestion),
        content: Text(l10n.escrowConfirmNote(amount)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.escrowNotNow),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.escrowConfirmYes),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.confirm();
  }

  Future<void> _dispute(BuildContext context) async {
    final cubit = context.read<EscrowCubit>();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const DisputeDialog(),
    );
    if (reason != null) await cubit.dispute(reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final escrow = info.escrow;
    final status = escrow?.status;
    final amount = formatPounds(info.amountPiastres);
    final releaseAt = escrow?.releaseAt;
    final releaseMoment = releaseAt == null ? '' : momentLabel(l10n, releaseAt);
    final consumerConfirmed = escrow?.consumerConfirmed ?? false;
    final technicianConfirmed = escrow?.technicianConfirmed ?? false;
    final body = switch (status) {
      null when info.paymentInProgress => l10n.escrowPaymentCheckingBody,
      null => l10n.escrowOfferBody(honorific, amount),
      EscrowStatus.pending => l10n.escrowPendingBody,
      EscrowStatus.held when consumerConfirmed && technicianConfirmed =>
        l10n.escrowHeldBothConfirmedBody(releaseMoment),
      EscrowStatus.held when consumerConfirmed =>
        l10n.escrowHeldYouConfirmedBody(honorific),
      EscrowStatus.held when technicianConfirmed =>
        l10n.escrowHeldTechnicianConfirmedBody(honorific, releaseMoment),
      EscrowStatus.held => l10n.escrowHeldBody(amount),
      EscrowStatus.paidOut => l10n.escrowPaidOutBody,
      EscrowStatus.disputed => l10n.escrowDisputedBody,
      EscrowStatus.refundDue => l10n.escrowRefundDueBody,
      EscrowStatus.refunded => l10n.escrowRefundedBody,
      EscrowStatus.rejected => l10n.escrowRejectedBody(
        escrow?.rejectReason ?? '',
      ),
    };
    final secureLabel =
        status == EscrowStatus.rejected || info.paymentInProgress
        ? l10n.escrowRetryAction(honorific)
        : l10n.escrowSecureAction(honorific);
    return AppCard(
      color: colors.successSoft,
      borderColor: colors.successBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, color: colors.success),
              const SizedBox(width: 8),
              Text(
                l10n.escrowTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 15, height: 1.6)),
          if (info.canSecure) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => unawaited(_secure(context)),
              child: Text(secureLabel),
            ),
          ],
          if (info.canConfirm) ...[
            const SizedBox(height: 12),
            BusyFilledButton(
              label: l10n.escrowConfirmAction,
              isBusy: busy,
              onPressed: () => unawaited(_confirm(context)),
            ),
          ],
          if (info.canDispute)
            TextButton(
              onPressed: busy ? null : () => unawaited(_dispute(context)),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              child: Text(l10n.escrowDisputeAction),
            ),
        ],
      ),
    );
  }
}
