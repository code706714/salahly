import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/normalize.dart';

void main() {
  test('trims and collapses whitespace, newlines included', () {
    expect(normalizeText('  ماسورة \n\t نحاس  '), 'ماسورة نحاس');
  });

  test('drops control characters the server refuses', () {
    expect(normalizeText('تنظيف\u0000 تكييف\u0085'), 'تنظيف تكييف');
  });

  test('is null when nothing is left', () {
    expect(normalizeText('   '), isNull);
    expect(normalizeText(null), isNull);
  });
}
