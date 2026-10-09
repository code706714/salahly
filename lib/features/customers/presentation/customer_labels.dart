import 'dart:math';

import 'package:intl/intl.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "female" or "male", for the strings that change with the customer:
/// عليه or عليها.
String customerGender(String name) =>
    hasFeminineTitle(name) ? 'female' : 'male';

/// What the customers list tells about a customer after their area: a
/// visit today, work finished today, the next visit, the last one, or
/// what they have.
String customerActivity(
  AppLocalizations l10n,
  CustomerSummary summary, {
  required DateTime today,
}) {
  final gender = customerGender(summary.customer.name);
  final next = summary.nextScheduledAt;
  final finished = summary.lastFinishedAt;
  if (next != null && CalendarDate.daysBetween(today, next) == 0) {
    return l10n.customersNextJob(gender, l10n.today);
  }
  if (finished != null && CalendarDate.daysBetween(finished, today) == 0) {
    return l10n.customersFinishedToday;
  }
  if (next != null) {
    return l10n.customersNextJob(gender, _visitDay(l10n, next, today));
  }
  if (finished != null) return _lastJob(l10n, finished, today);
  if (summary.unitCount > 0) return l10n.customersUnitCount(summary.unitCount);
  return l10n.jobCount(summary.jobCount);
}

/// "بكره", "السبت" within the week, else "15 أكتوبر".
String _visitDay(AppLocalizations l10n, DateTime day, DateTime today) {
  final days = CalendarDate.daysBetween(today, day);
  if (days == 1) return l10n.tomorrow;
  if (days < 7) return weekdayName(day);
  return shortDate(day, today: today);
}

/// "آخر شغلانة من 6 أيام", in months after a month and years after a year.
String _lastJob(AppLocalizations l10n, DateTime finished, DateTime today) {
  final days = CalendarDate.daysBetween(finished, today);
  if (days < 30) return l10n.customersLastJobDays(days);
  var months = (today.year - finished.year) * 12 + today.month - finished.month;
  if (today.day < finished.day) months--;
  if (months < 12) return l10n.customersLastJobMonths(max(months, 1));
  return l10n.customersLastJobYears(months ~/ 12);
}

/// "26 سبتمبر", with the year when it is not [today]'s: "3 مايو 2023".
String shortDate(DateTime day, {required DateTime today}) => DateFormat(
  day.year == today.year ? 'd MMMM' : 'd MMMM y',
  'ar',
).format(day);

/// A service date the way it is said: "النهارده", "بكره", "أول أبريل" or
/// "15 أبريل"; with the year only when it is over a year ahead or in an
/// earlier year.
String serviceDayLabel(
  AppLocalizations l10n,
  DateTime day, {
  required DateTime today,
}) {
  final days = CalendarDate.daysBetween(today, day);
  if (days == 0) return l10n.today;
  if (days == 1) return l10n.tomorrow;
  final withinYear = day.year == today.year || (days > 0 && days < 365);
  final month = DateFormat.MMMM('ar').format(day);
  final date = day.day == 1
      ? l10n.customerFirstOfMonth(month)
      : DateFormat('d MMMM', 'ar').format(day);
  return withinYear ? date : '$date ${day.year}';
}

/// Horsepower without trailing zeros: 1.5, 2.25, 3.
String formatHp(double hp) => NumberFormat('0.##', 'en').format(hp);

/// A unit in one line: "شارب 1.5 حصان · الصالة".
String unitTitle(AppLocalizations l10n, CustomerUnit unit) {
  final capacity = unit.capacityHp;
  final model = [
    ?unit.brand,
    if (capacity != null) l10n.unitHp(formatHp(capacity)),
  ].join(' ');
  final title = [if (model.isNotEmpty) model, ?unit.room].join(' · ');
  return title.isEmpty ? l10n.unitUntitled : title;
}

/// "شغلانة جديدة لكريم", by the customer's first name.
String newJobForLabel(AppLocalizations l10n, String customerName) {
  final first = firstNameOf(customerName);
  if (first.isEmpty) return l10n.newJob;
  // ل before ال drops the alef: السيد → للسيد.
  return l10n.customerNewJobFor(
    first.startsWith('ال') ? first.substring(1) : first,
  );
}
