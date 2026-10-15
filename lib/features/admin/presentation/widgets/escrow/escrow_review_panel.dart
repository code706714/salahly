import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/escrow_review_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_facts.dart';
import 'package:salahly/features/admin/presentation/widgets/review_checklist.dart';
import 'package:salahly/features/admin/presentation/widgets/secure_image.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The longest reference or note the server takes.
const _referenceMaxLength = 100;
const _noteMaxLength = 300;

/// One guaranteed payment: the transfer's screenshot beside who is involved,
/// and the one step the team takes next.
///
/// Every step moves money or promises it, so each asks to confirm, and
/// confirming the consumer's transfer needs the checklist ticked.
class EscrowReviewPanel extends StatefulWidget {
  const EscrowReviewPanel({required this.escrow, super.key});

  final EscrowReview escrow;

  @override
  State<EscrowReviewPanel> createState() => _EscrowReviewPanelState();
}

class _EscrowReviewPanelState extends State<EscrowReviewPanel> {
  final Set<int> _checked = {};

  EscrowReview get _escrow => widget.escrow;

  String _consumer(AppLocalizations l10n) =>
      _escrow.consumerName ?? l10n.adminDeletedAccount;

  String _technician(AppLocalizations l10n) =>
      _escrow.technicianName ?? l10n.adminDeletedAccount;

  Future<void> _approve(AppLocalizations l10n) async {
    final cubit = context.read<EscrowReviewCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminEscrowApproveTitle(_consumer(l10n)),
      body: l10n.adminEscrowApproveBody(formatPounds(_escrow.amountPiastres)),
      confirmLabel: l10n.adminEscrowApproveConfirm,
    );
    if (confirmed) await cubit.approve(_escrow.id);
  }

  Future<void> _reject(AppLocalizations l10n) async {
    final cubit = context.read<EscrowReviewCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminTopupsRejectTitle(_consumer(l10n)),
      body: l10n.adminTopupsRejectBody,
      confirmLabel: l10n.adminTopupsRejectConfirm,
      fieldLabel: l10n.adminReasonLabel,
      quickReasons: [
        l10n.adminTopupsReasonAmount,
        l10n.adminTopupsReasonNotFound,
      ],
    );
    if (reason != null) await cubit.reject(_escrow.id, reason);
  }

  Future<void> _markPaid(AppLocalizations l10n) async {
    final cubit = context.read<EscrowReviewCubit>();
    final reference = await showReasonDialog(
      context,
      title: l10n.adminEscrowPayTitle(_technician(l10n)),
      body: l10n.adminEscrowPayBody(formatPounds(_escrow.amountPiastres)),
      confirmLabel: l10n.adminEscrowPayConfirm,
      fieldLabel: l10n.adminEscrowReferenceLabel,
      maxLength: _referenceMaxLength,
      destructive: false,
    );
    if (reference != null) await cubit.markPaid(_escrow.id, reference);
  }

  Future<void> _markRefunded(AppLocalizations l10n) async {
    final cubit = context.read<EscrowReviewCubit>();
    final reference = await showReasonDialog(
      context,
      title: l10n.adminEscrowRefundTitle(_consumer(l10n)),
      body: l10n.adminEscrowRefundBody(
        formatPounds(_escrow.amountPiastres),
        _escrow.senderAccount ?? '',
      ),
      confirmLabel: l10n.adminEscrowRefundConfirm,
      fieldLabel: l10n.adminEscrowReferenceLabel,
      maxLength: _referenceMaxLength,
      destructive: false,
    );
    if (reference != null) await cubit.markRefunded(_escrow.id, reference);
  }

  Future<void> _refundOnline(AppLocalizations l10n) async {
    final cubit = context.read<EscrowReviewCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminEscrowRefundTitle(_consumer(l10n)),
      body: l10n.adminEscrowRefundOnlineBody(
        formatPounds(_escrow.amountPiastres),
      ),
      confirmLabel: l10n.adminEscrowRefundOnlineConfirm,
    );
    if (confirmed) await cubit.refundOnline(_escrow.id);
  }

  Future<void> _resolve(
    AppLocalizations l10n, {
    required bool payTechnician,
  }) async {
    final cubit = context.read<EscrowReviewCubit>();
    final note = await showReasonDialog(
      context,
      title: l10n.adminEscrowResolveTitle,
      body: payTechnician
          ? l10n.adminEscrowResolveTechnicianBody
          : l10n.adminEscrowResolveConsumerBody,
      confirmLabel: payTechnician
          ? l10n.adminEscrowResolveTechnicianConfirm
          : l10n.adminEscrowResolveConsumerConfirm,
      fieldLabel: l10n.adminEscrowNoteLabel,
      maxLength: _noteMaxLength,
      destructive: false,
    );
    if (note != null) {
      await cubit.resolve(
        _escrow.id,
        payTechnician: payTechnician,
        note: note,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final escrow = _escrow;
    final now = context.watch<ClockCubit>().state;
    final isBusy = context.select<EscrowReviewCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    final checks = [
      l10n.adminTopupsCheckAmount,
      l10n.adminTopupsCheckFound,
      l10n.adminTopupsCheckUnique,
      l10n.adminTopupsCheckTime,
    ];

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
                      _consumer(l10n),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      l10n.adminEscrowRowLine(
                        escrow.requestCode,
                        formatPounds(escrow.amountPiastres),
                        adminAgeLabel(l10n, escrow.createdAt, now: now),
                      ),
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: adminEscrowStatusLabel(l10n, escrow.status),
                tone: adminEscrowStatusTone(escrow.status),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (escrow.screenshotPath case final screenshot?) ...[
                SizedBox(
                  width: 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.adminEscrowScreenshot,
                        style: TextStyle(fontSize: 13, color: colors.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      SecureImage(
                        bucket: AdminBucket.transferProofs,
                        path: screenshot,
                        label: l10n.adminEscrowScreenshot,
                        aspectRatio: 0.8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminFacts(
                      facts: [
                        AdminFact(
                          label: l10n.adminEscrowAmount,
                          value: Text(
                            '${formatPounds(escrow.amountPiastres)} '
                            '${l10n.currencyEgp}',
                          ),
                        ),
                        if (escrow.isOnline)
                          AdminFact(
                            label: l10n.adminTopupsMethod,
                            value: Text(
                              l10n.adminEscrowOnline(
                                escrow.onlineMethod ?? '-',
                              ),
                            ),
                          )
                        else ...[
                          AdminFact(
                            label: l10n.adminTopupsMethod,
                            value: Text(
                              topupMethodLabel(l10n, escrow.method!),
                            ),
                          ),
                          AdminFact(
                            label: l10n.adminEscrowFrom,
                            value: _ltr(escrow.senderAccount!),
                          ),
                        ],
                        AdminFact(
                          label: l10n.adminEscrowConsumer,
                          value: _person(
                            _consumer(l10n),
                            escrow.consumerPhone,
                          ),
                        ),
                        AdminFact(
                          label: l10n.adminEscrowTechnician,
                          value: _person(
                            _technician(l10n),
                            escrow.technicianPhone,
                          ),
                        ),
                        if (escrow.payoutAccount case final account?)
                          AdminFact(
                            label: l10n.adminEscrowPayTo,
                            value: _ltr(
                              '$account · '
                              '${topupMethodLabel(l10n, escrow.payoutMethod!)}',
                            ),
                          ),
                        if (escrow.payoutHolder case final holder?)
                          AdminFact(
                            label: l10n.adminEscrowPayoutHolder,
                            value: Text(holder),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ..._next(l10n, colors, isBusy, checks),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// What the team does with this payment now, or what happened to it.
  List<Widget> _next(
    AppLocalizations l10n,
    AppColors colors,
    bool isBusy,
    List<String> checks,
  ) {
    final escrow = _escrow;
    return switch (escrow.status) {
      EscrowStatus.pending => [
        ReviewChecklist(
          title: l10n.adminTopupsChecklist(_checked.length, checks.length),
          labels: checks,
          checked: _checked,
          onToggle: (index) => setState(() {
            if (!_checked.remove(index)) _checked.add(index);
          }),
        ),
        const SizedBox(height: 16),
        BusyFilledButton(
          label: l10n.adminEscrowApprove,
          isBusy: isBusy,
          onPressed: _checked.length == checks.length
              ? () => _approve(l10n)
              : null,
        ),
        const SizedBox(height: 8),
        _dangerButton(
          colors,
          l10n.adminVerifyReject,
          isBusy ? null : () => _reject(l10n),
        ),
      ],
      EscrowStatus.released => [
        if (escrow.payoutAccount == null)
          _warning(colors, l10n.adminEscrowPayoutMissing),
        if (escrow.payoutAccount == null) const SizedBox(height: 16),
        BusyFilledButton(
          label: l10n.adminEscrowPayAction,
          isBusy: isBusy,
          onPressed: escrow.payoutAccount == null
              ? null
              : () => _markPaid(l10n),
        ),
      ],
      EscrowStatus.disputed => [
        if (escrow.disputeReason case final reason?) ...[
          _warning(colors, l10n.adminEscrowDisputeReason(reason)),
          const SizedBox(height: 16),
        ],
        BusyFilledButton(
          label: l10n.adminEscrowResolveTechnician,
          isBusy: isBusy,
          onPressed: () => _resolve(l10n, payTechnician: true),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: isBusy ? null : () => _resolve(l10n, payTechnician: false),
          child: Text(l10n.adminEscrowResolveConsumer),
        ),
      ],
      EscrowStatus.refundDue => [
        if (escrow.isOnline) ...[
          BusyFilledButton(
            label: l10n.adminEscrowRefundOnlineAction,
            isBusy: isBusy,
            onPressed: () => _refundOnline(l10n),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: isBusy ? null : () => _markRefunded(l10n),
            child: Text(l10n.adminEscrowRefundAction),
          ),
        ] else
          BusyFilledButton(
            label: l10n.adminEscrowRefundAction,
            isBusy: isBusy,
            onPressed: () => _markRefunded(l10n),
          ),
      ],
      EscrowStatus.paidOut ||
      EscrowStatus.refunded ||
      EscrowStatus.held ||
      EscrowStatus.rejected => [
        if (escrow.payoutReference case final reference?)
          Text(l10n.adminEscrowPaidReference(reference)),
        if (escrow.refundReference case final reference?)
          Text(l10n.adminEscrowRefundedReference(reference)),
        if (escrow.resolutionNote case final note?)
          Text(l10n.adminEscrowResolution(note)),
        if (escrow.rejectReason case final reason?)
          Text(
            l10n.adminTopupsRejectedReason(reason),
            style: TextStyle(color: colors.dangerDeep),
          ),
      ],
    };
  }

  static Widget _ltr(String text) =>
      Directionality(textDirection: TextDirection.ltr, child: Text(text));

  static Widget _person(String name, String? phone) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(name),
      if (phone != null) _ltr(adminPhoneLabel(phone)),
    ],
  );

  static Widget _warning(AppColors colors, String text) => DecoratedBox(
    decoration: BoxDecoration(
      color: colors.warningSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, height: 1.5, color: colors.warning),
      ),
    ),
  );

  static Widget _dangerButton(
    AppColors colors,
    String label,
    VoidCallback? onPressed,
  ) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      foregroundColor: colors.dangerDeep,
      side: BorderSide(color: colors.dangerLine, width: 1.5),
    ),
    onPressed: onPressed,
    child: Text(label),
  );
}
