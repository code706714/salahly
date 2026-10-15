import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/live_refresh.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/presentation/cubit/technician_escrow_cubit.dart';
import 'package:salahly/features/escrow/presentation/escrow_failure_message.dart';
import 'package:salahly/features/escrow/presentation/widgets/dispute_dialog.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Tells the picked technician where the consumer's money stands, and lets
/// him confirm the work or object to it. Shows nothing when she did not pay
/// in.
class TechnicianEscrowNotice extends StatelessWidget {
  const TechnicianEscrowNotice({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = TechnicianEscrowCubit(
          escrow: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const _NoticeView(),
    );
  }
}

class _NoticeView extends StatelessWidget {
  const _NoticeView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TechnicianEscrowCubit>();
    return LiveRefresh(
      onChange: () => unawaited(cubit.load()),
      child: BlocConsumer<TechnicianEscrowCubit, TechnicianEscrowState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                technicianEscrowFailureMessage(
                  AppLocalizations.of(context),
                  state.failure!,
                ),
              ),
            ),
          ),
        builder: (context, state) {
          final escrow = state.escrow;
          if (escrow == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _Body(escrow: escrow, busy: state.busy),
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.escrow, required this.busy});

  final TechnicianEscrow escrow;
  final bool busy;

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TechnicianEscrowCubit>();
    final amount = formatPounds(escrow.amountPiastres);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.escrowConfirmQuestion),
        content: Text(l10n.technicianEscrowConfirmNote(amount)),
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
    final cubit = context.read<TechnicianEscrowCubit>();
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
    final amount = formatPounds(escrow.amountPiastres);
    final releaseAt = escrow.releaseAt;
    final releaseMoment = releaseAt == null ? '' : momentLabel(l10n, releaseAt);
    final text = switch (escrow.status) {
      EscrowStatus.pending => l10n.technicianEscrowPending(amount),
      EscrowStatus.held
          when escrow.consumerConfirmed && escrow.technicianConfirmed =>
        l10n.technicianEscrowBothConfirmed(amount, releaseMoment),
      EscrowStatus.held when escrow.technicianConfirmed =>
        l10n.technicianEscrowYouConfirmed(releaseMoment, amount),
      EscrowStatus.held when escrow.consumerConfirmed =>
        l10n.technicianEscrowConsumerConfirmed(amount),
      EscrowStatus.held when escrow.canConfirm => l10n.technicianEscrowFinished(
        amount,
      ),
      EscrowStatus.held => l10n.technicianEscrowHeld(amount),
      EscrowStatus.paidOut => l10n.technicianEscrowPaidOut(amount),
      EscrowStatus.disputed => l10n.technicianEscrowDisputed,
      EscrowStatus.refundDue ||
      EscrowStatus.refunded ||
      EscrowStatus.rejected => l10n.technicianEscrowRefunded,
    };
    return AppCard(
      color: colors.successSoft,
      borderColor: colors.successBright,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: colors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (escrow.canConfirm) ...[
            const SizedBox(height: 12),
            BusyFilledButton(
              label: l10n.technicianEscrowConfirmAction,
              isBusy: busy,
              onPressed: () => unawaited(_confirm(context)),
            ),
          ],
          if (escrow.canDispute)
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
