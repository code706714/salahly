import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';

import '../../pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  test('names the part of the day the way Egyptians say it', () {
    expect(
      [7, 13, 16, 18, 21, 2].map(
        (hour) =>
            partOfDayLabel(l10n, PartOfDay.of(DateTime(2026, 10, 2, hour))),
      ),
      ['الصبح', 'الضهر', 'العصر', 'المغرب', 'بالليل', 'بالليل'],
    );
  });

  test('reads a time on a 12-hour dial', () {
    expect(timeLabel(l10n, DateTime(2026, 10, 2, 13)), '1:00 الضهر');
    expect(timeLabel(l10n, DateTime(2026, 10, 2, 0, 5)), '12:05 بالليل');
  });

  test('names nearby days and dates the rest', () {
    final today = DateTime(2026, 10, 2, 22);

    expect(dayLabel(l10n, DateTime(2026, 10, 2, 8), today: today), 'النهارده');
    expect(dayLabel(l10n, DateTime(2026, 10, 3), today: today), 'بكره');
    expect(dayLabel(l10n, DateTime(2026, 10), today: today), 'امبارح');
    expect(
      dayLabel(l10n, DateTime(2026, 10, 5), today: today),
      'الاثنين 5 أكتوبر',
    );
  });
}
