import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/money.dart';

void main() {
  group('formatPounds', () {
    test('groups whole pounds with Western digits', () {
      expect(formatPounds(0), '0');
      expect(formatPounds(145000), '1,450');
      expect(formatPounds(1840000), '18,400');
    });

    test('shows piastres only when there are some', () {
      expect(formatPounds(1250), '12.50');
      expect(formatPounds(120005), '1,200.05');
    });
  });

  group('parsePounds', () {
    test('reads whole pounds typed with or without grouping', () {
      expect(parsePounds('1450'), 145000);
      expect(parsePounds(' 1,450 '), 145000);
    });

    test('reads Arabic digits and the Arabic thousands separator', () {
      expect(parsePounds('١٬٤٥٠'), 145000);
    });

    test('rejects anything that is not a whole number', () {
      expect(parsePounds(''), isNull);
      expect(parsePounds('12.5'), isNull);
      expect(parsePounds('-5'), isNull);
      expect(parsePounds('خمسين'), isNull);
    });
  });
}
