import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';

void main() {
  test('spells enum values the way the server does', () {
    expect(toWire(RequestWindow.anyTime), 'any_time');
    expect(toWire(ComplaintReason.noShowOrLate), 'no_show_or_late');
    expect(toWire(ReviewTag.respectful), 'respectful');
  });

  test('reads the server names back', () {
    expect(
      enumFromWire(RequestWindow.values, 'any_time'),
      RequestWindow.anyTime,
    );
    expect(
      () => enumFromWire(RequestWindow.values, 'midnight'),
      throwsFormatException,
    );
  });

  test('skips names this version does not know in a set', () {
    expect(enumSetFromWire(ReviewTag.values, ['on_time', 'fast', 'on_time']), {
      ReviewTag.onTime,
    });
    expect(enumSetFromWire(ReviewTag.values, null), isEmpty);
  });

  test('reads times as local time and dates as local midnight', () {
    final time = timeFromWire('2026-10-03T09:00:00+00:00');
    expect(time.isUtc, isFalse);
    expect(time.toUtc(), DateTime.utc(2026, 10, 3, 9));
    expect(dateFromWire('2026-10-03'), DateTime(2026, 10, 3));
    expect(() => dateFromWire('03/10/2026'), throwsFormatException);
  });
}
