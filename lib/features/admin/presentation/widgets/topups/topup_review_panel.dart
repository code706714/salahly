import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/topup_review_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_facts.dart';
import 'package:salahly/features/admin/presentation/widgets/review_checklist.dart';
import 'package:salahly/features/admin/presentation/widgets/secure_image.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One transfer: the screenshot the person uploaded beside what the team
/// checks it against, and the buttons that confirm or reject it.
///
/// Approving adds uses to the person's balance, so it asks twice: the
/// checklist must be ticked, and the button asks to confirm.
class TopupReviewPanel extends StatefulWidget {
  const TopupReviewPanel({required this.topup, super.key});

  final TopupReview topup;

  @override
  State<TopupReviewPanel> createState() => _TopupReviewPanelState();
}

class _TopupReviewPanelState extends State<TopupReviewPanel> {
  final Set<int> _checked = {};

  String _pack(AppLocalizations l10n) =>
      adminPackLabel(l10n, widget.topup.role, widget.topup.uses);

  String _name(AppLocalizations l10n) =>
      widget.topup.name ?? l10n.adminDeletedAccount;

  Future<void> _approve(AppLocalizations l10n) async {
    final cubit = context.read<TopupReviewCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminTopupsApproveTitle(_name(l10n)),
      body: l10n.adminTopupsApproveBody(
        _pack(l10n),
        formatPounds(widget.topup.amountPiastres),
      ),
      confirmLabel: l10n.adminTopupsApproveConfirm,
    );
    if (confirmed) await cubit.approve(widget.topup.id);
  }

  Future<void> _reject(AppLocalizations l10n) async {
    final cubit = context.read<TopupReviewCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminTopupsRejectTitle(_name(l10n)),
      body: l10n.adminTopupsRejectBody,
      confirmLabel: l10n.adminTopupsRejectConfirm,
      fieldLabel: l10n.adminReasonLabel,
      quickReasons: [
        l10n.adminTopupsReasonAmount,
        l10n.adminTopupsReasonNotFound,
      ],
    );
    if (reason != null) await cubit.reject(widget.topup.id, reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final topup = widget.topup;
    final now = context.watch<ClockCubit>().state;
    final isBusy = context.select<TopupReviewCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    final checks = [
      l10n.adminTopupsCheckAmount,
      l10n.adminTopupsCheckFound,
      l10n.adminTopupsCheckUnique,
      l10n.adminTopupsCheckTime,
    ];
    final role = switch (topup.role) {
      UserRole.consumer => l10n.adminTopupsRoleConsumer,
      UserRole.technician => l10n.adminTopupsRoleTechnician,
    };

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
                      _name(l10n),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${l10n.adminTopupsHeaderLine(role, _pack(l10n))} · '
                      '${adminAgeLabel(l10n, topup.createdAt, now: now)}',
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: adminTopupStatusLabel(l10n, topup.status),
                tone: switch (topup.status) {
                  TopupStatus.pending => PillTone.waiting,
                  TopupStatus.approved => PillTone.success,
                  TopupStatus.rejected => PillTone.danger,
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 240,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.adminTopupsScreenshot,
                      style: TextStyle(fontSize: 13, color: colors.inkMuted),
                    ),
                    const SizedBox(height: 6),
                    SecureImage(
                      bucket: AdminBucket.transferProofs,
                      path: topup.screenshotPath,
                      label: l10n.adminTopupsScreenshot,
                      aspectRatio: 0.8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AdminFacts(
                      facts: [
                        AdminFact(
                          label: l10n.adminTopupsAmount,
                          value: Text(
                            '${formatPounds(topup.amountPiastres)} '
                            '${l10n.currencyEgp}',
                          ),
                        ),
                        AdminFact(
                          label: l10n.adminTopupsMethod,
                          value: Text(topupMethodLabel(l10n, topup.method)),
                        ),
                        AdminFact(
                          label: l10n.adminTopupsFrom,
                          value: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(topup.senderAccount),
                          ),
                        ),
                        if (topup.accountPhone case final phone?)
                          AdminFact(
                            label: l10n.adminTopupsAccountPhone,
                            value: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(adminPhoneLabel(phone)),
                            ),
                          ),
                      ],
                    ),
                    if (topup.senderDiffersFromAccount) ...[
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.warningSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            l10n.adminTopupsDifferentSender,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: colors.warning,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (topup.status == TopupStatus.pending) ...[
                      ReviewChecklist(
                        title: l10n.adminTopupsChecklist(
                          _checked.length,
                          checks.length,
                        ),
                        labels: checks,
                        checked: _checked,
                        onToggle: (index) => setState(() {
                          if (!_checked.remove(index)) _checked.add(index);
                        }),
                      ),
                      const SizedBox(height: 16),
                      BusyFilledButton(
                        label: l10n.adminTopupsApprove,
                        isBusy: isBusy,
                        onPressed: _checked.length == checks.length
                            ? () => _approve(l10n)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.dangerDeep,
                          side: BorderSide(
                            color: colors.dangerLine,
                            width: 1.5,
                          ),
                        ),
                        onPressed: isBusy ? null : () => _reject(l10n),
                        child: Text(l10n.adminVerifyReject),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.adminTopupsNote,
                        style: TextStyle(fontSize: 13, color: colors.inkMuted),
                      ),
                    ] else if (topup.rejectReason case final reason?)
                      Text(
                        l10n.adminTopupsRejectedReason(reason),
                        style: TextStyle(color: colors.dangerDeep),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
