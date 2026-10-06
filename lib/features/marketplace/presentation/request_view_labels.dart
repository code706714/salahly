import 'dart:math';

import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A request's name in a header: "تكييف مش بيبرّد" with the [category]'s
/// name, or just the problem while the categories load.
String requestHeadline(
  AppLocalizations l10n,
  RequestIssue issue, {
  required String? category,
}) => category == null
    ? requestIssueLabel(l10n, issue)
    : requestTitle(l10n, issue, category: category);

/// A request's day said the short way, as requests are at most a week
/// ahead: "النهارده", "بكره", "الأحد"; further away, the date too.
String requestDayName(
  AppLocalizations l10n,
  DateTime day, {
  required DateTime today,
}) => switch (CalendarDate.daysBetween(today, day)) {
  0 => l10n.today,
  1 => l10n.tomorrow,
  -1 => l10n.yesterday,
  >= 2 && <= 6 => weekdayName(day),
  _ => weekdayDate(day),
};

/// The day and window a request asks for: "بكره · الضهر 12 لـ 3".
String requestWhenLabel(
  AppLocalizations l10n,
  DateTime day,
  RequestWindow window, {
  required DateTime today,
}) =>
    '${requestDayName(l10n, day, today: today)} · '
    '${requestWindowLabel(l10n, window)}';

/// How long ago a request was sent: "الطلب اتبعت من 40 دقيقة".
String requestSentAgoLabel(
  AppLocalizations l10n,
  DateTime sentAt, {
  required DateTime now,
}) {
  // The device's clock may run behind the server's.
  final elapsed = now.isBefore(sentAt) ? Duration.zero : now.difference(sentAt);
  return switch (elapsed) {
    Duration(inMinutes: < 60) => l10n.waitingSentMinutes(elapsed.inMinutes),
    Duration(inHours: < 24) => l10n.waitingSentHours(elapsed.inHours),
    _ => l10n.waitingSentDays(elapsed.inDays),
  };
}

/// How long ago a review was written, by calendar days: "امبارح",
/// "من أسبوعين", "من 3 شهور".
String reviewAgoLabel(
  AppLocalizations l10n,
  DateTime writtenAt, {
  required DateTime today,
}) {
  final days = max(0, CalendarDate.daysBetween(writtenAt, today));
  return switch (days) {
    < 7 => l10n.techProfileAgoDays(days),
    < 30 => l10n.techProfileAgoWeeks(days ~/ 7),
    < 365 => l10n.techProfileAgoMonths(days ~/ 30),
    _ => l10n.techProfileAgoYears(days ~/ 365),
  };
}
