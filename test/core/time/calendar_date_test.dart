import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/time/calendar_date.dart';

void main() {
  test('formats and parses yyyy-MM-dd', () {
    expect(CalendarDate.format(DateTime(2026, 4, 1, 15, 30)), '2026-04-01');
    expect(CalendarDate.tryParse('2026-04-01'), DateTime(2026, 4));
  });

  test('rejects anything else', () {
    expect(CalendarDate.tryParse('1/4/2026'), isNull);
    expect(CalendarDate.tryParse(null), isNull);
  });

  test('counts calendar days, not 24-hour periods', () {
    expect(
      CalendarDate.daysBetween(
        DateTime(2026, 10, 1, 23, 59),
        DateTime(2026, 10, 2, 0, 1),
      ),
      1,
    );
    expect(
      CalendarDate.daysBetween(DateTime(2026, 9, 20), DateTime(2026, 10, 2)),
      12,
    );
  });

  test('of drops the time of day', () {
    expect(
      CalendarDate.of(DateTime(2026, 10, 2, 13, 5)),
      DateTime(2026, 10, 2),
    );
  });
}
