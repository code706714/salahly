import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/features/money/presentation/money_labels.dart';

import '../../../pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  final today = DateTime(2026, 10, 2);

  test('names a month with its year in Western digits', () {
    expect(monthYear(DateTime(2026, 10)), 'أكتوبر 2026');
    expect(monthYear(DateTime(2025, 12)), 'ديسمبر 2025');
  });

  test('calls the current month income to date', () {
    expect(
      incomeTitle(l10n, DateTime(2026, 10), today: today),
      'دخل الشهر لحد النهارده',
    );
  });

  test('names an earlier month, with the year once it is another', () {
    expect(
      incomeTitle(l10n, DateTime(2026, 9), today: today),
      'دخل شهر سبتمبر',
    );
    expect(
      incomeTitle(l10n, DateTime(2025, 12), today: today),
      'دخل شهر ديسمبر 2025',
    );
  });
}
