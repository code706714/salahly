import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';
import 'package:salahly/features/money/presentation/cubit/money_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Everyone who owes money in one card, a row per job.
class OwedList extends StatelessWidget {
  const OwedList({
    required this.jobs,
    required this.today,
    required this.technicianName,
    super.key,
  });

  final List<OwedJob> jobs;
  final DateTime today;

  /// Signs the reminders.
  final String technicianName;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, owed) in jobs.indexed) ...[
            if (index > 0) const Divider(),
            _OwedRow(
              owed: owed,
              today: today,
              technicianName: technicianName,
            ),
          ],
        ],
      ),
    );
  }
}

class _OwedRow extends StatelessWidget {
  const _OwedRow({
    required this.owed,
    required this.today,
    required this.technicianName,
  });

  final OwedJob owed;
  final DateTime today;
  final String technicianName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final summary = owed.summary;
    final job = summary.job;
    final isOffline = context.select<SyncCubit, bool>(
      (cubit) => cubit.state.isOffline,
    );
    final work = jobTitle(l10n, job);
    final partlyPaid = summary.paidPiastres > 0;
    final due = paymentDueLabel(l10n, owed.due, today: today);
    final isLate = owed.due is PaymentLate;
    final action = switch (owed.due) {
      PaymentDueToday() => _RecordPaymentButton(
        onPressed: () => context.push(AppRoutes.jobInvoice(job.id)),
      ),
      _ when owed.canRemind => WhatsAppButton(
        label: hasFeminineTitle(summary.customerName)
            ? l10n.remindCustomerFeminine
            : l10n.remindCustomer,
        outlined: true,
        onPressed: () => context.sendOnWhatsApp(
          paymentReminderMessage(
            l10n,
            job: job,
            customerName: summary.customerName,
            balancePiastres: summary.balancePiastres,
            technicianName: technicianName,
          ),
          to: summary.customerPhone,
        ),
      ),
      _ => null,
    };

    return InkWell(
      onTap: () => context.push(AppRoutes.job(job.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    partlyPaid
                        ? l10n.moneyOwedRest(
                            work,
                            formatPounds(summary.balancePiastres),
                            formatPounds(summary.totalPiastres),
                          )
                        : l10n.moneyOwedAll(
                            work,
                            formatPounds(summary.balancePiastres),
                          ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: colors.inkMuted),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      StatusPill(
                        label: partlyPaid ? l10n.moneyPartlyPaid(due) : due,
                        tone: isLate ? PillTone.danger : PillTone.waiting,
                        icon: isLate
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                      ),
                      if (isOffline && !summary.isSynced)
                        StatusPill(
                          label: l10n.jobPendingSync,
                          tone: PillTone.waiting,
                          icon: Icons.schedule_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 12), action],
          ],
        ),
      ),
    );
  }
}

/// Opens the invoice to record the money received today.
class _RecordPaymentButton extends StatelessWidget {
  const _RecordPaymentButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.inkSoft,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Text(
                AppLocalizations.of(context).moneyRecordPayment,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
