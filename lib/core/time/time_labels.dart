import 'package:intl/intl.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "الصبح", "الضهر", ...
String partOfDayLabel(AppLocalizations l10n, PartOfDay period) =>
    switch (period) {
      PartOfDay.morning => l10n.periodMorning,
      PartOfDay.noon => l10n.periodNoon,
      PartOfDay.afternoon => l10n.periodAfternoon,
      PartOfDay.sunset => l10n.periodSunset,
      PartOfDay.night => l10n.periodNight,
    };

/// The time the way it is said: "1:00 الضهر".
String timeLabel(AppLocalizations l10n, DateTime time) =>
    '${clockTime(time)} ${partOfDayLabel(l10n, PartOfDay.of(time))}';

/// The weekday: "الخميس".
String weekdayName(DateTime day) => DateFormat.EEEE('ar').format(day);

/// The weekday and date: "الخميس 2 أكتوبر".
String weekdayDate(DateTime day) => DateFormat('EEEE d MMMM', 'ar').format(day);

/// "النهارده", "بكره" or "امبارح" when [day] is that close to [today],
/// else the weekday and date.
String dayLabel(
  AppLocalizations l10n,
  DateTime day, {
  required DateTime today,
}) => switch (CalendarDate.daysBetween(today, day)) {
  0 => l10n.today,
  1 => l10n.tomorrow,
  -1 => l10n.yesterday,
  _ => weekdayDate(day),
};
