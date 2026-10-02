import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/digits.dart';

void main() {
  group('normalizeDigits', () {
    test('converts Arabic-Indic digits to ASCII', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Persian digits to ASCII', () {
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('converts only the digits of mixed text', () {
      expect(normalizeDigits('كود صلحلي: ١٢٣ 456'), 'كود صلحلي: 123 456');
    });

    test('keeps characters outside the Basic Multilingual Plane', () {
      expect(normalizeDigits('٣😀'), '3😀');
    });

    test('returns an empty string unchanged', () {
      expect(normalizeDigits(''), '');
    });
  });

  group('digitsOnly', () {
    test('drops everything that is not a digit', () {
      expect(digitsOnly('+20 (100) 234-5678'), '201002345678');
    });

    test('keeps Arabic-Indic and Persian digits as ASCII', () {
      expect(digitsOnly('٠١٠ ۲۳۴ 5678'), '0102345678');
    });

    test('returns an empty string when there are no digits', () {
      expect(digitsOnly('كود صلحلي'), '');
    });
  });

  group('parseWholeNumber', () {
    test('reads Western and Arabic digits', () {
      expect(parseWholeNumber('350'), 350);
      expect(parseWholeNumber('٣٥٠'), 350);
    });

    test('allows surrounding spaces', () {
      expect(parseWholeNumber(' 12 '), 12);
    });

    test('rejects a decimal point instead of dropping it', () {
      expect(parseWholeNumber('150.5'), isNull);
    });

    test('rejects signs, separators and letters', () {
      expect(parseWholeNumber('-5'), isNull);
      expect(parseWholeNumber('1,500'), isNull);
      expect(parseWholeNumber('12a'), isNull);
    });

    test('rejects an empty string', () {
      expect(parseWholeNumber(''), isNull);
    });
  });
}
