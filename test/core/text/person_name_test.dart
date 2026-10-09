import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/person_name.dart';

void main() {
  group('normalizeName', () {
    test('trims surrounding whitespace', () {
      expect(normalizeName('  محمد أحمد \n'), 'محمد أحمد');
    });

    test('collapses inner runs of whitespace to one space', () {
      expect(normalizeName('محمد   \t أحمد\nعلي'), 'محمد أحمد علي');
    });

    test('leaves an already normalised name unchanged', () {
      expect(normalizeName('ورشة الأمل'), 'ورشة الأمل');
    });
  });

  group('isValidName', () {
    test('accepts a two-letter name', () {
      expect(isValidName('مي'), isTrue);
    });

    test('accepts a 60-character name', () {
      expect(isValidName('م' * 60), isTrue);
    });

    test('rejects a single letter', () {
      expect(isValidName('م'), isFalse);
    });

    test('rejects a 61-character name', () {
      expect(isValidName('م' * 61), isFalse);
    });

    test('rejects empty and blank input', () {
      expect(isValidName(''), isFalse);
      expect(isValidName('   '), isFalse);
    });

    test('measures the length after trimming', () {
      expect(isValidName('  م  '), isFalse);
    });

    test('measures the length after collapsing inner whitespace', () {
      final name = '${'أ' * 30}${' ' * 10}${'ب' * 29}';

      expect(name.length, greaterThan(60));
      expect(isValidName(name), isTrue);
    });
  });

  group('firstNameOf', () {
    test('skips titles', () {
      expect(firstNameOf('أ. كريم منصور'), 'كريم');
      expect(firstNameOf('مدام  سهير عبد الله'), 'سهير');
      expect(firstNameOf('نورهان'), 'نورهان');
      expect(firstNameOf('عبد الرحمن علي'), 'عبد الرحمن');
    });

    test('is empty for a title alone', () {
      expect(firstNameOf('أستاذ'), '');
    });
  });

  group('initialsOf', () {
    test('takes two letters, skipping titles and the article', () {
      expect(initialsOf('أ. كريم منصور'), 'ك م');
      expect(initialsOf('مدام سهير عبد الله'), 'س ع');
      expect(initialsOf('نورهان'), 'ن');
      expect(initialsOf('محمود السيد'), 'م س');
      expect(initialsOf('عبد الرحمن الشريف'), 'ع ش');
      expect(initialsOf('محمد عبد الله'), 'م ع');
      expect(initialsOf('ال'), 'ا');
    });
  });

  group('hasFeminineTitle', () {
    test('reads titles only women use', () {
      expect(hasFeminineTitle('مدام سهير عبد الله'), isTrue);
      expect(hasFeminineTitle('أ. كريم منصور'), isFalse);
      expect(hasFeminineTitle('سهير'), isFalse);
    });
  });
}
