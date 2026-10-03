import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The invoice itself: who it is from and when, its lines, the total, what
/// was paid and what is left.
class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    required this.details,
    required this.technicianName,
    required this.technicianPhone,
    required this.issuedOn,
    super.key,
  });

  final JobDetails details;
  final String technicianName;
  final PhoneNumber? technicianPhone;
  final DateTime issuedOn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final phone = technicianPhone;
    final balance = details.balancePiastres;
    final balanceColor = balance > 0 ? colors.danger : colors.success;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: colors.ink,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.invoiceSignature(technicianName),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colors.background,
                          ),
                        ),
                        if (phone != null)
                          Text(
                            phone.local,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onInkMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('d MMMM y', 'ar').format(issuedOn),
                    style: TextStyle(fontSize: 13, color: colors.onInkMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          for (final item in details.items)
            _Line(
              label: item.quantity == 1
                  ? item.title
                  : '${item.title} × ${item.quantity}',
              amount: formatPounds(item.totalPiastres),
            ),
          if (details.items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Divider(color: colors.divider),
          ],
          _Line(
            label: l10n.invoiceTotal,
            amount: l10n.pounds(formatPounds(details.totalPiastres)),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            labelBold: true,
          ),
          _Line(
            label: l10n.invoicePaid,
            amount: l10n.pounds(formatPounds(details.paidPiastres)),
            style: TextStyle(fontSize: 15, color: colors.success),
          ),
          _Line(
            label: l10n.invoiceBalance,
            amount: l10n.pounds(formatPounds(balance)),
            style: TextStyle(fontSize: 15, color: balanceColor),
            amountStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: balanceColor,
            ),
            labelBold: true,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.amount,
    this.style = const TextStyle(fontSize: 15),
    this.amountStyle,
    this.labelBold = false,
  });

  final String label;
  final String amount;
  final TextStyle style;
  final TextStyle? amountStyle;
  final bool labelBold;

  @override
  Widget build(BuildContext context) {
    final bold = style.copyWith(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: labelBold ? bold : style)),
          const SizedBox(width: 8),
          Text(amount, style: amountStyle ?? bold),
        ],
      ),
    );
  }
}
