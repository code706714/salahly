import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/quote/quote_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The WhatsApp message carrying a job's invoice:
///
///     أهلاً م. شريف عادل، دي فاتورة رقم 0127:
///     • تركيب سبليت 2.25 حصان: 900 ج.م
///     الإجمالي: 900 ج.م
///     اتدفع: 500 ج.م
///     الباقي: 400 ج.م
///     تقدر تدفع كاش أو تحويل إنستاباي أو فودافون كاش.
///
///     محمود السيد · فني صيانة
///     0100 234 5678
///
/// A settled invoice thanks the customer instead of asking for the rest.
String invoiceMessage(
  AppLocalizations l10n, {
  required JobDetails details,
  required String technicianName,
  required PhoneNumber? technicianPhone,
}) {
  final customerName = details.customer.name;
  final gender = hasFeminineTitle(customerName) ? 'female' : 'male';
  final number = details.job.invoiceNumber;
  final paid = details.paidPiastres;
  final balance = details.balancePiastres;
  return [
    if (number == null)
      l10n.invoiceMessageGreetingUnnumbered(customerName)
    else
      l10n.invoiceMessageGreeting(customerName, invoiceNumberLabel(number)),
    for (final item in details.items)
      itemLine(
        l10n,
        title: item.title,
        quantity: item.quantity,
        totalPiastres: item.totalPiastres,
      ),
    l10n.quoteMessageTotal(formatPounds(details.totalPiastres)),
    if (balance == 0)
      l10n.invoiceMessageSettled(gender)
    else ...[
      if (paid > 0) ...[
        l10n.invoiceMessagePaid(formatPounds(paid)),
        l10n.invoiceMessageBalance(formatPounds(balance)),
      ],
      l10n.invoiceMessageHowToPay(gender),
    ],
    '',
    ...technicianSignature(l10n, technicianName, technicianPhone),
  ].join('\n');
}
