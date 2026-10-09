import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_detail_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/verification_review_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_facts.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/review_checklist.dart';
import 'package:salahly/features/admin/presentation/widgets/secure_image.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One technician's submission: who they are, their three photos, the
/// reviewer's checklist, and the buttons that approve or reject it.
///
/// Opening it is recorded in the audit log, so the submission is fetched
/// once when this is built and not again until it is built anew.
class VerificationReview extends StatelessWidget {
  const VerificationReview({
    required this.verificationId,
    required this.onReviewed,
    super.key,
  });

  final String verificationId;

  /// Runs once the submission was approved or rejected.
  final VoidCallback onReviewed;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = VerificationDetailCubit(
              context.read<VerificationRepository>(),
              verificationId: verificationId,
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) => VerificationReviewCubit(
            context.read<VerificationRepository>(),
            verificationId: verificationId,
          ),
        ),
      ],
      child: AdminActionListener<VerificationReviewCubit>(
        onChanged: onReviewed,
        child: BlocBuilder<VerificationDetailCubit, VerificationDetailState>(
          builder: (context, state) {
            final detail = state.detail;
            if (detail != null) return _Detail(detail: detail);
            if (state.failure case final failure?) {
              return AdminFailureView(
                failure: failure,
                onRetry: context.read<VerificationDetailCubit>().load,
              );
            }
            return const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    );
  }
}

class _Detail extends StatefulWidget {
  const _Detail({required this.detail});

  final VerificationDetail detail;

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final Set<int> _checked = {};

  Future<void> _approve(AppLocalizations l10n) async {
    final cubit = context.read<VerificationReviewCubit>();
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminVerifyApproveTitle(widget.detail.name),
      body: l10n.adminVerifyApproveBody,
      confirmLabel: l10n.adminVerifyApproveConfirm,
    );
    if (confirmed) await cubit.approve();
  }

  Future<void> _reject(AppLocalizations l10n) async {
    final cubit = context.read<VerificationReviewCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminVerifyRejectTitle(widget.detail.name),
      body: l10n.adminVerifyRejectBody,
      confirmLabel: l10n.adminVerifyRejectConfirm,
      fieldLabel: l10n.adminReasonLabel,
      quickReasons: [
        l10n.adminVerifyReasonBlurry,
        l10n.adminVerifyReasonName,
        l10n.adminVerifyReasonExpired,
        l10n.adminVerifyReasonFace,
      ],
    );
    if (reason != null) await cubit.reject(reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final detail = widget.detail;
    final now = context.watch<ClockCubit>().state;
    final checks = [
      l10n.adminVerifyCheckName,
      l10n.adminVerifyCheckFace,
      l10n.adminVerifyCheckValid,
      l10n.adminVerifyCheckTrade,
    ];
    final isBusy = context.select<VerificationReviewCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );

    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InitialsAvatar(name: detail.name, size: 54),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      detail.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      l10n.adminVerifyHeaderLine(
                        detail.area.name,
                        adminAgeLabel(l10n, detail.submittedAt, now: now),
                      ),
                      style: TextStyle(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
              if (detail.suspended) ...[
                StatusPill(
                  label: l10n.adminVerifySuspended,
                  tone: PillTone.danger,
                ),
                const SizedBox(width: 8),
              ],
              StatusPill(
                label: verificationStatusLabel(l10n, detail.status),
                tone: verificationStatusTone(detail.status),
              ),
            ],
          ),
          if (detail.previousAttempts > 0) ...[
            const SizedBox(height: 8),
            Text(
              l10n.adminVerifyPreviousAttempts(detail.previousAttempts),
              style: TextStyle(color: colors.warning),
            ),
          ],
          const SizedBox(height: 20),
          AdminFacts(
            facts: [
              AdminFact(
                label: l10n.adminVerifyPhone,
                value: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CopyablePhone(detail.phone),
                    StatusPill(
                      label: detail.phoneConfirmed
                          ? l10n.adminVerifyPhoneConfirmed
                          : l10n.adminVerifyPhoneUnconfirmed,
                      tone: detail.phoneConfirmed
                          ? PillTone.success
                          : PillTone.waiting,
                    ),
                  ],
                ),
              ),
              AdminFact(
                label: l10n.adminVerifyExperience,
                value: Text(l10n.adminVerifyYears(detail.yearsExperience)),
              ),
              if (detail.shopName != null)
                AdminFact(
                  label: l10n.adminVerifyShop,
                  value: Text(detail.shopName!),
                ),
              AdminFact(
                label: l10n.adminVerifyBase,
                value: Text(detail.area.name),
              ),
              AdminFact(
                label: l10n.adminVerifyRadius,
                value: Text(l10n.adminVerifyRadiusKm(detail.serviceRadiusKm)),
              ),
              AdminFact(
                label: l10n.adminVerifyAreas,
                value: Text(detail.areas.map((area) => area.name).join('، ')),
              ),
              AdminFact(
                label: l10n.adminVerifyDays,
                value: Text(
                  (detail.workDays.toList()..sort())
                      .map((day) => weekdayShortName(l10n, day))
                      .join('، '),
                ),
              ),
            ],
          ),
          if (detail.services.isNotEmpty) ...[
            const SizedBox(height: 14),
            AdminFact(
              label: l10n.adminVerifyServices,
              value: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final service in detail.services)
                    StatusPill(
                      label:
                          '${service.name} · '
                          '${formatPounds(service.startingPricePiastres)} '
                          '${l10n.currencyEgp}',
                      tone: PillTone.neutral,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (label, path) in [
                (l10n.adminVerifyIdFront, detail.idFrontPath),
                (l10n.adminVerifyIdBack, detail.idBackPath),
                (l10n.adminVerifySelfie, detail.selfiePath),
              ]) ...[
                if (path != detail.idFrontPath) const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SecureImage(
                        bucket: AdminBucket.verificationDocs,
                        path: path,
                        label: label,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: colors.inkMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          if (detail.isPending) ...[
            ReviewChecklist(
              title: l10n.adminVerifyChecklist(_checked.length, checks.length),
              labels: checks,
              checked: _checked,
              onToggle: (index) => setState(() {
                if (!_checked.remove(index)) _checked.add(index);
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: BusyFilledButton(
                    label: l10n.adminVerifyApprove,
                    isBusy: isBusy,
                    onPressed: _checked.length == checks.length
                        ? () => _approve(l10n)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.dangerDeep,
                      side: BorderSide(color: colors.dangerLine, width: 1.5),
                    ),
                    onPressed: isBusy ? null : () => _reject(l10n),
                    child: Text(l10n.adminVerifyReject),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.adminVerifyNote,
              style: TextStyle(fontSize: 13, color: colors.inkMuted),
            ),
          ] else if (detail.rejectionReason case final reason?)
            Text(
              l10n.adminVerifyRejectedReason(reason),
              style: TextStyle(color: colors.dangerDeep),
            ),
        ],
      ),
    );
  }
}
