import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/withdrawal_review_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_facts.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The longest transfer reference the server takes.
const _referenceMaxLength = 100;

/// One withdrawal: who asked, how much and where to send it, and the one
/// step the team takes next. Sending money asks to confirm.
class WithdrawalReviewPanel extends StatelessWidget {
  const WithdrawalReviewPanel({required this.withdrawal, super.key});

  final WithdrawalReview withdrawal;

  String _technician(AppLocalizations l10n) =>
      withdrawal.technicianName ?? l10n.adminDeletedAccount;

  Future<void> _markPaid(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<WithdrawalReviewCubit>();
    final reference = await showReasonDialog(
      context,
      title: l10n.adminWithdrawalPayTitle(_technician(l10n)),
      body: l10n.adminWithdrawalPayBody(
        formatPounds(withdrawal.amountPiastres),
      ),
      confirmLabel: l10n.adminWithdrawalPayConfirm,
      fieldLabel: l10n.adminWithdrawalReference,
      maxLength: _referenceMaxLength,
      destructive: false,
    );
    if (reference != null) await cubit.markPaid(withdrawal.id, reference);
  }

  Future<void> _reject(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<WithdrawalReviewCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminWithdrawalRejectTitle(_technician(l10n)),
      body: l10n.adminWithdrawalRejectBody,
      confirmLabel: l10n.adminWithdrawalRejectConfirm,
      fieldLabel: l10n.adminReasonLabel,
      quickReasons: [l10n.adminWithdrawalReasonAccount],
    );
    if (reason != null) await cubit.reject(withdrawal.id, reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final now = context.watch<ClockCubit>().state;
    final isBusy = context.select<WithdrawalReviewCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _technician(l10n),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      l10n.adminWithdrawalRowLine(
                        formatPounds(withdrawal.amountPiastres),
                        adminAgeLabel(l10n, withdrawal.createdAt, now: now),
                      ),
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: adminWithdrawalStatusLabel(l10n, withdrawal.status),
                tone: adminWithdrawalStatusTone(withdrawal.status),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AdminFacts(
            facts: [
              AdminFact(
                label: l10n.adminWithdrawalAmount,
                value: Text(
                  '${formatPounds(withdrawal.amountPiastres)} '
                  '${l10n.currencyEgp}',
                ),
              ),
              AdminFact(
                label: l10n.adminTopupsMethod,
                value: Text(topupMethodLabel(l10n, withdrawal.method)),
              ),
              AdminFact(
                label: l10n.adminWithdrawalSendTo,
                value: _ltr(withdrawal.account),
              ),
              AdminFact(
                label: l10n.adminWithdrawalHolder,
                value: Text(withdrawal.holderName),
              ),
              AdminFact(
                label: l10n.adminWithdrawalTechnician,
                value: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_technician(l10n)),
                    if (withdrawal.technicianPhone case final phone?)
                      _ltr(adminPhoneLabel(phone)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._next(context, l10n, colors, isBusy),
        ],
      ),
    );
  }

  /// What the team does with this request now, or what happened to it.
  List<Widget> _next(
    BuildContext context,
    AppLocalizations l10n,
    AppColors colors,
    bool isBusy,
  ) {
    return switch (withdrawal.status) {
      WithdrawalStatus.requested => [
        BusyFilledButton(
          label: l10n.adminWithdrawalPayAction,
          isBusy: isBusy,
          onPressed: () => _markPaid(context, l10n),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.dangerDeep,
            side: BorderSide(color: colors.dangerLine, width: 1.5),
          ),
          onPressed: isBusy ? null : () => _reject(context, l10n),
          child: Text(l10n.adminWithdrawalRejectAction),
        ),
      ],
      WithdrawalStatus.paid => [
        if (withdrawal.reference case final reference?)
          Text(l10n.adminWithdrawalPaidReference(reference)),
      ],
      WithdrawalStatus.rejected => [
        if (withdrawal.rejectReason case final reason?)
          Text(
            l10n.adminTopupsRejectedReason(reason),
            style: TextStyle(color: colors.dangerDeep),
          ),
      ],
    };
  }

  static Widget _ltr(String text) =>
      Directionality(textDirection: TextDirection.ltr, child: Text(text));
}
