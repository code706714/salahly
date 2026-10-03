import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/presentation/quote/quote_message.dart';

import '../../../../pump_app.dart';

void main() {
  const items = [
    JobItemDraft(title: 'تركيب سبليت 2.25 حصان', unitPricePiastres: 90000),
    JobItemDraft(
      title: 'ماسورة نحاس (المتر)',
      unitPricePiastres: 10000,
      quantity: 4,
    ),
    JobItemDraft(title: 'حامل الوحدة الخارجية', unitPricePiastres: 15000),
  ];
  final phone = PhoneNumber.tryParse('01002345678');

  test('lists the lines, the total and how long it holds, then signs', () {
    final message = quoteMessage(
      l10n,
      customerName: 'م. شريف عادل',
      items: items,
      validDays: 3,
      toBook: true,
      technicianName: 'محمود السيد',
      technicianPhone: phone,
    );

    expect(
      message,
      'أهلاً م. شريف عادل، ده عرض السعر:\n'
      '• تركيب سبليت 2.25 حصان: 900 ج.م\n'
      '• ماسورة نحاس (المتر) × 4: 400 ج.م\n'
      '• حامل الوحدة الخارجية: 150 ج.م\n'
      'الإجمالي: 1,450 ج.م\n'
      'العرض ساري 3 أيام.\n'
      '\n'
      'لو موافق ابعتلي "تمام" وأنا أثبّتلك المعاد.\n'
      'محمود السيد · فني تكييف\n'
      '\u20660100 234 5678\u2069',
    );
  });

  test('asks a woman, and a booked customer, the right way', () {
    final message = quoteMessage(
      l10n,
      customerName: 'مدام سهير عبد الله',
      items: items.take(1).toList(),
      validDays: 1,
      toBook: false,
      technicianName: 'محمود السيد',
      technicianPhone: null,
    );

    expect(message, contains('العرض ساري يوم.'));
    expect(message, contains('لو موافقة ابعتلي "تمام".'));
    expect(message, isNot(contains('المعاد')));
    expect(message, endsWith('محمود السيد · فني تكييف'));
  });

  test('says how long it holds in Egyptian counting', () {
    String validity(int days) => quoteMessage(
      l10n,
      customerName: 'أ. كريم',
      items: items,
      validDays: days,
      toBook: false,
      technicianName: 'محمود',
      technicianPhone: null,
    ).split('\n').firstWhere((line) => line.startsWith('العرض'));

    expect(validity(2), 'العرض ساري يومين.');
    expect(validity(7), 'العرض ساري 7 أيام.');
    expect(validity(14), 'العرض ساري 14 يوم.');
  });

  test('a line names its count only when there is more than one', () {
    expect(
      itemLine(l10n, title: 'تنظيف', quantity: 1, totalPiastres: 25000),
      '• تنظيف: 250 ج.م',
    );
    expect(
      itemLine(l10n, title: 'تنظيف', quantity: 2, totalPiastres: 50000),
      '• تنظيف × 2: 500 ج.م',
    );
  });
}
