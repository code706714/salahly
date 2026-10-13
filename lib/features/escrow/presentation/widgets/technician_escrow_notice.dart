import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/live_refresh.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/presentation/cubit/technician_escrow_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Tells the picked technician whether the consumer's money is secured.
/// Shows nothing when she did not pay in.
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
      child: BlocBuilder<TechnicianEscrowCubit, TechnicianEscrow?>(
        builder: (context, escrow) {
          if (escrow == null) return const SizedBox.shrink();
          final l10n = AppLocalizations.of(context);
          final colors = context.appColors;
          final amount = formatPounds(escrow.amountPiastres);
          final payoutReminder =
              escrow.status == EscrowStatus.held ||
              escrow.status == EscrowStatus.released;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AppCard(
              color: colors.successSoft,
              borderColor: colors.successBright,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.verified_user_outlined, color: colors.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch (escrow.status) {
                            EscrowStatus.pending =>
                              l10n.technicianEscrowPending(amount),
                            EscrowStatus.held => l10n.technicianEscrowHeld(
                              amount,
                            ),
                            EscrowStatus.released =>
                              l10n.technicianEscrowReleased(amount),
                            EscrowStatus.paidOut =>
                              l10n.technicianEscrowPaidOut(amount),
                            EscrowStatus.disputed =>
                              l10n.technicianEscrowDisputed,
                            EscrowStatus.refundDue ||
                            EscrowStatus.refunded ||
                            EscrowStatus.rejected =>
                              l10n.technicianEscrowRefunded,
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (payoutReminder)
                          Text(
                            l10n.technicianEscrowNoPayout,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: colors.inkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
