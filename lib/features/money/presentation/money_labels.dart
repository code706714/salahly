import 'package:intl/intl.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The month and its year: "أكتوبر 2026".
String monthYear(DateTime month) => DateFormat('MMMM y', 'ar').format(month);

/// What a month's income is called: "دخل الشهر لحد النهارده" for the
/// current month, else "دخل شهر سبتمبر", with the year when it is not
/// [today]'s.
String incomeTitle(
  AppLocalizations l10n,
  DateTime month, {
  required DateTime today,
}) {
  if (month.year == today.year && month.month == today.month) {
    return l10n.moneyIncomeToDate;
  }
  return l10n.moneyIncomeOf(
    month.year == today.year
        ? DateFormat.MMMM('ar').format(month)
        : monthYear(month),
  );
}
