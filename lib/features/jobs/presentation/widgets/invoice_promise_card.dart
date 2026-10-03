import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The day the customer promised to pay: "وعد يدفع السبت", with ways to
/// pick, change or clear it.
class InvoicePromiseCard extends StatelessWidget {
  const InvoicePromiseCard({
    required this.promisedOn,
    required this.today,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  /// Local midnight, or null when there is no promise.
  final DateTime? promisedOn;
  final DateTime today;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final promisedOn = this.promisedOn;
    return AppCard(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 4, 8),
      child: Row(
        children: [
          Icon(Icons.event_outlined, size: 22, color: colors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promisedOn == null
                        ? l10n.invoicePromiseTitle
                        : paymentDueLabel(
                            l10n,
                            PaymentPromised(promisedOn),
                            today: today,
                          ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (promisedOn == null)
                    Text(
                      l10n.invoicePromiseHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            child: Text(
              promisedOn == null
                  ? l10n.invoicePromisePick
                  : l10n.invoicePromiseChange,
            ),
          ),
          if (promisedOn != null)
            IconButton(
              onPressed: onClear,
              tooltip: l10n.invoicePromiseClear,
              color: colors.inkMuted,
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}
