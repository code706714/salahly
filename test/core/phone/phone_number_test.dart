import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/phone/phone_number.dart';

void main() {
  group('PhoneNumber.tryParse', () {
    const operators = {
      'Vodafone': '1002345678',
      'Etisalat': '1112345678',
      'Orange': '1212345678',
      'WE': '1512345678',
    };

    for (final MapEntry(key: operator, value: national) in operators.entries) {
      group('accepts a $operator number', () {
        test('typed without the leading 0', () {
          expect(PhoneNumber.tryParse(national)?.nationalNumber, national);
        });

        test('typed with the leading 0', () {
          expect(PhoneNumber.tryParse('0$national')?.nationalNumber, national);
        });

        test('typed with the +20 country code', () {
          expect(
            PhoneNumber.tryParse('+20$national')?.nationalNumber,
            national,
          );
        });
      });
    }

    test('accepts the country code without a plus sign', () {
      expect(PhoneNumber.tryParse('201002345678')?.e164, '+201002345678');
    });

    test('accepts the country code followed by the leading 0', () {
      expect(PhoneNumber.tryParse('+20 0100 234 5678')?.e164, '+201002345678');
    });

    test('ignores spaces and dashes', () {
      expect(PhoneNumber.tryParse('+20 100 234 5678')?.e164, '+201002345678');
      expect(PhoneNumber.tryParse('0100-234-5678')?.e164, '+201002345678');
    });

    test('reads Arabic-Indic and Persian digits', () {
      expect(PhoneNumber.tryParse('٠١٠٠٢٣٤٥٦٧٨')?.e164, '+201002345678');
      expect(PhoneNumber.tryParse('۰۱۰۰ ۲۳۴ ۵۶۷۸')?.e164, '+201002345678');
    });

    const invalid = {
      'empty input': '',
      'no digits': 'رقمي',
      'a number one digit short': '100234567',
      'an unassigned 013 prefix': '01302345678',
      'an unassigned 014 prefix': '01402345678',
      'an unassigned 016 prefix': '01602345678',
      'a Cairo landline': '0223456789',
      'a number not starting with 1': '2002345678',
    };

    for (final MapEntry(key: description, value: input) in invalid.entries) {
      test('rejects $description', () {
        expect(PhoneNumber.tryParse(input), isNull);
      });
    }

    test('accepts the 0020 international prefix', () {
      expect(PhoneNumber.tryParse('00201002345678')?.e164, '+201002345678');
    });

    test('rejects a number with extra digits instead of cutting it', () {
      expect(PhoneNumber.tryParse('010023456789'), isNull);
    });

    test('parses every spelling of a number to equal values', () {
      expect(
        PhoneNumber.tryParse('٠١٠٠ ٢٣٤ ٥٦٧٨'),
        PhoneNumber.tryParse('+201002345678'),
      );
    });
  });

  group('PhoneNumber', () {
    final phone = PhoneNumber.tryParse('01002345678')!;

    test('formats as E.164', () {
      expect(phone.e164, '+201002345678');
    });

    test('groups the national number as 3-3-4', () {
      expect(phone.grouped, '100 234 5678');
    });

    test('writes the local form with a leading 0', () {
      expect(phone.local, '0100 234 5678');
    });

    test('gives the digits WhatsApp links need', () {
      expect(phone.international, '201002345678');
    });
  });

  group('nationalDigitsFrom', () {
    test('drops a leading 0', () {
      expect(nationalDigitsFrom('0100'), '100');
    });

    test('drops a typed country code once longer than a national number', () {
      expect(nationalDigitsFrom('+201002345678'), '1002345678');
    });

    test('keeps a leading 20 while it could still be the country code', () {
      expect(nationalDigitsFrom('+2010'), '2010');
    });

    test('drops both the country code and a following 0', () {
      expect(nationalDigitsFrom('+20 0100 234 5678'), '1002345678');
    });

    test('caps the result at 10 digits', () {
      expect(nationalDigitsFrom('10023456789'), '1002345678');
    });

    test('keeps only the digits, read as ASCII', () {
      expect(nationalDigitsFrom('١٠٠-٢٣٤ x'), '100234');
    });

    test('returns an empty string for no digits', () {
      expect(nationalDigitsFrom(''), '');
    });
  });

  group('groupNationalDigits', () {
    const cases = {
      '': '',
      '10': '10',
      '100': '100',
      '1002': '100 2',
      '100234': '100 234',
      '1002345': '100 234 5',
      '1002345678': '100 234 5678',
    };

    for (final MapEntry(key: digits, value: grouped) in cases.entries) {
      test('groups "$digits" as "$grouped"', () {
        expect(groupNationalDigits(digits), grouped);
      });
    }
  });
}
