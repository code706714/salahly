import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/text/arabic_search.dart';

void main() {
  group('foldArabic', () {
    test('folds hamza and madda alef forms to a bare alef', () {
      expect(foldArabic('أكتوبر'), 'اكتوبر');
      expect(foldArabic('إمبابة'), 'امبابه');
      expect(foldArabic('آمنة'), 'امنه');
    });

    test('folds taa marbuta to haa', () {
      expect(foldArabic('الجيزة'), 'الجيزه');
    });

    test('folds alef maqsura to yaa', () {
      expect(foldArabic('مستشفى'), 'مستشفي');
    });

    test('removes harakat, tanween and shadda', () {
      expect(foldArabic('مُحَمَّد'), 'محمد');
      expect(foldArabic('شُكْرًا'), 'شكرا');
    });

    test('removes tatweel', () {
      expect(foldArabic('مـــصر'), 'مصر');
    });

    test('trims surrounding whitespace', () {
      expect(foldArabic('  مدينة نصر '), 'مدينه نصر');
    });

    test('folds what people type and the stored name to the same text', () {
      expect(foldArabic('6 اكتوبر'), foldArabic('6 أكتوبر'));
      expect(foldArabic('المعادى'), foldArabic('المعادي'));
    });

    test('leaves non-Arabic text unchanged', () {
      expect(foldArabic('Maadi 2'), 'Maadi 2');
    });
  });
}
