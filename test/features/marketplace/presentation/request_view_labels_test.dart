import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';

import '../../../pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  final today = DateTime(2026, 10, 6, 22);

  test('names a request with its trade once the trades load', () {
    expect(
      requestHeadline(l10n, RequestIssue.notCooling, category: 'تكييف'),
      'تكييف مش بيبرّد',
    );
    expect(
      requestHeadline(l10n, RequestIssue.notCooling, category: null),
      'مش بيبرّد',
    );
  });

  test('names the days of the coming week, and dates the rest', () {
    expect(
      requestDayName(l10n, DateTime(2026, 10, 6, 9), today: today),
      'النهارده',
    );
    expect(requestDayName(l10n, DateTime(2026, 10, 7), today: today), 'بكره');
    expect(requestDayName(l10n, DateTime(2026, 10, 5), today: today), 'امبارح');
    expect(
      requestDayName(l10n, DateTime(2026, 10, 9), today: today),
      weekdayName(DateTime(2026, 10, 9)),
    );
    expect(
      requestDayName(l10n, DateTime(2026, 10, 14), today: today),
      weekdayDate(DateTime(2026, 10, 14)),
    );
    expect(
      requestDayName(l10n, DateTime(2026, 10, 2), today: today),
      weekdayDate(DateTime(2026, 10, 2)),
    );
  });

  test('says the day and the window', () {
    expect(
      requestWhenLabel(
        l10n,
        DateTime(2026, 10, 7),
        RequestWindow.noon,
        today: today,
      ),
      'بكره · الضهر 12 لـ 3',
    );
  });

  test('says how long ago a request was sent', () {
    final sent = DateTime(2026, 10, 6, 9);
    String ago(Duration elapsed) =>
        requestSentAgoLabel(l10n, sent, now: sent.add(elapsed));

    expect(ago(Duration.zero), 'الطلب اتبعت دلوقتي');
    expect(ago(const Duration(minutes: 40)), 'الطلب اتبعت من 40 دقيقة');
    expect(ago(const Duration(minutes: 5)), 'الطلب اتبعت من 5 دقايق');
    expect(ago(const Duration(hours: 2, minutes: 10)), 'الطلب اتبعت من ساعتين');
    expect(ago(const Duration(days: 3)), 'الطلب اتبعت من 3 أيام');
    expect(
      requestSentAgoLabel(
        l10n,
        sent,
        now: sent.subtract(const Duration(minutes: 3)),
      ),
      'الطلب اتبعت دلوقتي',
    );
  });

  test('says how long ago a review was written, by calendar days', () {
    String ago(DateTime written) => reviewAgoLabel(l10n, written, today: today);

    expect(ago(DateTime(2026, 10, 6, 23)), 'النهارده');
    expect(ago(DateTime(2026, 10, 5, 23)), 'امبارح');
    expect(ago(DateTime(2026, 10, 3)), 'من 3 أيام');
    expect(ago(DateTime(2026, 9, 22)), 'من أسبوعين');
    expect(ago(DateTime(2026, 7, 6)), 'من 3 شهور');
    expect(ago(DateTime(2024, 10, 6)), 'من سنتين');
  });
}
