import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/complaints_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_facts.dart';
import 'package:salahly/features/admin/presentation/widgets/secure_image.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One complaint: what the customer said, who it is between, and the two
/// things the team can do about it: close it, or suspend the technician.
///
/// What the customer wrote is shown as plain text.
class ComplaintCard extends StatelessWidget {
  const ComplaintCard({required this.complaint, super.key});

  final AdminComplaint complaint;

  Future<void> _resolve(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<ComplaintActionsCubit>();
    final note = await showReasonDialog(
      context,
      title: l10n.adminComplaintResolveTitle,
      body: l10n.adminComplaintResolveBody,
      confirmLabel: l10n.adminComplaintResolveConfirm,
      fieldLabel: l10n.adminComplaintNoteLabel,
      maxLength: noteMaxLength,
      destructive: false,
    );
    if (note != null) await cubit.resolve(complaint.id, note);
  }

  Future<void> _suspend(BuildContext context, AppLocalizations l10n) async {
    final cubit = context.read<ComplaintActionsCubit>();
    final reason = await showReasonDialog(
      context,
      title: l10n.adminSuspendTitle(complaint.technician.name),
      body: l10n.adminSuspendBody,
      confirmLabel: l10n.adminSuspendConfirm,
      fieldLabel: l10n.adminReasonLabel,
    );
    if (reason != null) {
      await cubit.suspendTechnician(complaint.technician.id, reason);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final now = context.watch<ClockCubit>().state;
    final isBusy = context.select<ComplaintActionsCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    final photoPath = complaint.photoPath;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adminComplaintReasonLabel(l10n, complaint.reason),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              StatusPill(
                label: complaint.isResolved
                    ? l10n.adminComplaintResolved
                    : l10n.adminComplaintOpen,
                tone: complaint.isResolved ? PillTone.success : PillTone.danger,
              ),
            ],
          ),
          Text(
            '${l10n.adminComplaintRequest} '
            '${complaint.requestCode} · '
            '${requestIssueLabel(l10n, complaint.issue)} · '
            '${adminAgeLabel(l10n, complaint.createdAt, now: now)}',
            style: TextStyle(color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  complaint.details ?? l10n.adminComplaintNoDetails,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.6,
                    color: complaint.details == null ? colors.inkMuted : null,
                  ),
                ),
              ),
              if (photoPath != null) ...[
                const SizedBox(width: 16),
                SizedBox(
                  width: 180,
                  child: SecureImage(
                    bucket: AdminBucket.requestPhotos,
                    path: photoPath,
                    label: l10n.adminComplaintPhoto,
                    aspectRatio: 1.3,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AdminFacts(
            facts: [
              _Party(
                label: l10n.adminComplaintFrom,
                role: l10n.adminComplaintCustomer,
                party: complaint.consumer,
              ),
              _Party(
                label: l10n.adminComplaintAbout,
                role: l10n.adminComplaintTechnician,
                party: complaint.technician,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (complaint.isResolved)
            Text(
              l10n.adminComplaintResolutionNote(complaint.resolutionNote ?? ''),
              style: TextStyle(color: colors.success),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: colors.ink,
                    foregroundColor: colors.background,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: isBusy
                      ? null
                      : () => unawaited(_resolve(context, l10n)),
                  child: Text(l10n.adminComplaintResolve),
                ),
                if (!complaint.technician.suspended)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.dangerDeep,
                    ),
                    onPressed: isBusy
                        ? null
                        : () => unawaited(_suspend(context, l10n)),
                    child: Text(l10n.adminComplaintSuspend),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Party extends StatelessWidget {
  const _Party({
    required this.label,
    required this.role,
    required this.party,
  });

  final String label;
  final String role;
  final ComplaintParty party;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AdminFact(
      label: '$label $role',
      value: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${party.name} · '),
          CopyablePhone(party.phone),
          if (party.suspended)
            StatusPill(
              label: l10n.adminComplaintTechnicianSuspended,
              tone: PillTone.danger,
            ),
        ],
      ),
    );
  }
}
