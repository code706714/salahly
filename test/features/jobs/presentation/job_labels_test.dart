import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';

import '../../../helpers/job_fixtures.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  group('jobTitle', () {
    test('joins the problems picked', () {
      expect(
        jobTitle(l10n, testJob(tags: [JobTag.cleaning, JobTag.freon])),
        'تنظيف + شحن فريون',
      );
    });

    test('falls back to the first line of the description', () {
      expect(
        jobTitle(
          l10n,
          testJob(tags: [], description: 'تركيب سبليت 2.25 حصان\nالدور التالت'),
        ),
        'تركيب سبليت 2.25 حصان',
      );
    });

    test('says "شغلانة" when nothing was written', () {
      expect(jobTitle(l10n, testJob(tags: [])), l10n.jobUntitled);
    });
  });

  group('paymentDueLabel', () {
    final today = DateTime(2026, 10, 2);

    test('names a promise within the week by its weekday', () {
      expect(
        paymentDueLabel(
          l10n,
          PaymentPromised(DateTime(2026, 10, 4)),
          today: today,
        ),
        'وعد يدفع الأحد',
      );
    });

    test('says tomorrow for a promise tomorrow', () {
      expect(
        paymentDueLabel(
          l10n,
          PaymentPromised(DateTime(2026, 10, 3)),
          today: today,
        ),
        'وعد يدفع بكره',
      );
    });

    test('counts late days the Egyptian way', () {
      expect(
        paymentDueLabel(l10n, const PaymentLate(1), today: today),
        'متأخر يوم',
      );
      expect(
        paymentDueLabel(l10n, const PaymentLate(2), today: today),
        'متأخر يومين',
      );
      expect(
        paymentDueLabel(l10n, const PaymentLate(6), today: today),
        'متأخر 6 أيام',
      );
      expect(
        paymentDueLabel(l10n, const PaymentLate(12), today: today),
        'متأخر 12 يوم',
      );
    });
  });

  test('the confirmation message names the day, time and work', () {
    final message = confirmationMessage(
      l10n,
      job: testJob(
        tags: [JobTag.cleaning, JobTag.freon],
        scheduledAt: DateTime(2026, 10, 3, 16, 30),
      ),
      customerName: 'مدام نادية سمير',
      technicianName: 'محمود عبد الله',
      today: DateTime(2026, 10, 2, 9),
    );

    expect(
      message,
      'أهلاً مدام نادية سمير، معانا ميعاد بكره الساعة 4:30 العصر '
      '(تنظيف + شحن فريون). لو الميعاد مناسب ابعتلي "تمام".\n'
      'محمود عبد الله',
    );
  });
}
