import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The WhatsApp message carrying a quote:
///
///     أهلاً م. شريف عادل، ده عرض السعر:
///     • تركيب سبليت 2.25 حصان: 900 ج.م
///     • ماسورة نحاس زيادة (المتر) × 4: 400 ج.م
///     الإجمالي: 1,300 ج.م
///     العرض ساري 3 أيام.
///
///     لو موافق ابعتلي "تمام" وأنا أثبّتلك المعاد.
///     محمود السيد · فني صيانة
///     0100 234 5678
///
/// [toBook] asks the customer to agree so the visit can be booked, for a
/// job not confirmed yet.
String quoteMessage(
  AppLocalizations l10n, {
  required String customerName,
  required List<JobItemDraft> items,
  required int validDays,
  required bool toBook,
  required String technicianName,
  required PhoneNumber? technicianPhone,
}) {
  final gender = hasFeminineTitle(customerName) ? 'female' : 'male';
  final total = items.fold(0, (sum, item) => sum + item.totalPiastres);
  return [
    l10n.quoteMessageGreeting(customerName),
    for (final item in items)
      itemLine(
        l10n,
        title: item.title,
        quantity: item.quantity,
        totalPiastres: item.totalPiastres,
      ),
    l10n.quoteMessageTotal(formatPounds(total)),
    '${l10n.quoteValidFor(validDays)}.',
    '',
    if (toBook)
      l10n.quoteMessageAskToBook(gender)
    else
      l10n.quoteMessageAsk(gender),
    ...technicianSignature(l10n, technicianName, technicianPhone),
  ].join('\n');
}

/// One line of a quote or invoice: "• ماسورة نحاس × 4: 400 ج.م".
String itemLine(
  AppLocalizations l10n, {
  required String title,
  required int quantity,
  required int totalPiastres,
}) {
  final amount = formatPounds(totalPiastres);
  return quantity == 1
      ? l10n.quoteMessageLine(title, amount)
      : l10n.quoteMessageLineQuantity(title, quantity, amount);
}

/// How the technician signs a message: their name and trade, then their
/// number when known, isolated left to right so its digit groups keep
/// their order inside Arabic text.
List<String> technicianSignature(
  AppLocalizations l10n,
  String name,
  PhoneNumber? phone,
) => [
  l10n.invoiceSignature(name),
  if (phone != null) '\u2066${phone.local}\u2069',
];
