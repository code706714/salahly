import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/widgets/pounds_field.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where the technician writes down money received: all of what is owed
/// or part of it, and how it was paid. The amount is saved from the
/// screen's main button.
class InvoiceRecordCard extends StatelessWidget {
  const InvoiceRecordCard({
    required this.amount,
    required this.amountFocus,
    required this.isFullAmount,
    required this.method,
    required this.onFullAmount,
    required this.onPartAmount,
    required this.onAmountChanged,
    required this.onMethod,
    this.errorText,
    super.key,
  });

  final TextEditingController amount;
  final FocusNode amountFocus;
  final bool isFullAmount;
  final PaymentMethod method;
  final VoidCallback onFullAmount;
  final VoidCallback onPartAmount;
  final ValueChanged<String> onAmountChanged;
  final ValueChanged<PaymentMethod> onMethod;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    const methods = PaymentMethod.values;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.primary, width: 2),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.invoiceRecordTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          SegmentedTabs(
            labels: [l10n.invoiceFullAmount, l10n.invoicePartAmount],
            selected: isFullAmount ? 0 : 1,
            onSelected: (index) => index == 0 ? onFullAmount() : onPartAmount(),
          ),
          const SizedBox(height: 14),
          Semantics(
            label: l10n.invoiceAmountLabel,
            child: PoundsField(
              controller: amount,
              focusNode: amountFocus,
              fontSize: 26,
              maxDigits: 6,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              errorText: errorText,
              onChanged: onAmountChanged,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.invoiceMethodQuestion,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          // Two a row, so "فودافون كاش" fits on the smallest phones.
          for (var row = 0; row < methods.length; row += 2) ...[
            if (row > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (final (index, item)
                    in methods.sublist(row, row + 2).indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChipButton(
                      label: paymentMethodLabel(l10n, item),
                      selected: item == method,
                      minHeight: 48,
                      onTap: () => onMethod(item),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
