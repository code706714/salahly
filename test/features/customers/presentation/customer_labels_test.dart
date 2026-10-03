import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/features/customers/presentation/customer_messages.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

import '../../../helpers/customer_fixtures.dart';
import '../../../helpers/job_fixtures.dart';
import '../../../pump_app.dart';

void main() {
  final today = DateTime(2026, 10, 2);

  setUpAll(() => initializeDateFormatting('ar'));

  group('customerGender', () {
    test('reads feminine titles', () {
      expect(customerGender('مدام سهير عبد الله'), 'female');
      expect(customerGender('أ. كريم منصور'), 'male');
    });
  });

  group('customerActivity', () {
    String activity({
      String name = 'أ. كريم منصور',
      DateTime? next,
      DateTime? finished,
      int units = 0,
      int jobs = 0,
    }) => customerActivity(
      l10n,
      testCustomerSummary(
        testCustomer(name: name),
        nextScheduledAt: next,
        lastFinishedAt: finished,
        unitCount: units,
        jobCount: jobs,
      ),
      today: today,
    );

    test('a visit today comes first', () {
      expect(
        activity(
          next: DateTime(2026, 10, 2, 13),
          finished: DateTime(2026, 10, 2, 9),
        ),
        'عنده شغلانة النهارده',
      );
      expect(
        activity(
          name: 'مدام سهير',
          next: DateTime(2026, 10, 2, 13),
        ),
        'عندها شغلانة النهارده',
      );
    });

    test('then work finished today', () {
      expect(
        activity(
          next: DateTime(2026, 10, 3, 13),
          finished: DateTime(2026, 10, 2, 9),
        ),
        'خلصت النهارده',
      );
    });

    test('then the next visit by its day', () {
      expect(
        activity(next: DateTime(2026, 10, 3, 13)),
        'عنده شغلانة بكره',
      );
      expect(
        activity(next: DateTime(2026, 10, 8, 13)),
        'عنده شغلانة الخميس',
      );
      expect(
        activity(next: DateTime(2026, 10, 15, 13)),
        'عنده شغلانة 15 أكتوبر',
      );
      expect(
        activity(next: DateTime(2027, 1, 15, 13)),
        'عنده شغلانة 15 يناير 2027',
      );
    });

    test('then how long ago the last job was', () {
      expect(
        activity(finished: DateTime(2026, 10, 1, 18)),
        'آخر شغلانة امبارح',
      );
      expect(
        activity(finished: DateTime(2026, 9, 30)),
        'آخر شغلانة من يومين',
      );
      expect(
        activity(finished: DateTime(2026, 9, 26)),
        'آخر شغلانة من 6 أيام',
      );
      expect(
        activity(finished: DateTime(2026, 9, 20)),
        'آخر شغلانة من 12 يوم',
      );
      expect(
        activity(finished: DateTime(2026, 9)),
        'آخر شغلانة من شهر',
      );
      expect(
        activity(finished: DateTime(2026, 7, 3)),
        'آخر شغلانة من شهرين',
      );
      expect(
        activity(finished: DateTime(2026, 4, 2)),
        'آخر شغلانة من 6 شهور',
      );
      expect(
        activity(finished: DateTime(2025, 10, 5)),
        'آخر شغلانة من 11 شهر',
      );
      expect(
        activity(finished: DateTime(2025, 10, 2)),
        'آخر شغلانة من سنة',
      );
      expect(
        activity(finished: DateTime(2023, 5, 3)),
        'آخر شغلانة من 3 سنين',
      );
    });

    test('then their units, then their jobs', () {
      expect(activity(units: 3), '3 تكييفات');
      expect(activity(units: 1), 'تكييف واحد');
      expect(activity(jobs: 2), 'شغلانتين');
      expect(activity(), 'مفيش شغلانات');
    });
  });

  test('shortDate adds the year only when it is not this one', () {
    expect(shortDate(DateTime(2026, 9, 26), today: today), '26 سبتمبر');
    expect(shortDate(DateTime(2023, 5, 3), today: today), '3 مايو 2023');
  });

  group('serviceDayLabel', () {
    String label(DateTime day) => serviceDayLabel(l10n, day, today: today);

    test('names today and tomorrow', () {
      expect(label(today), 'النهارده');
      expect(label(DateTime(2026, 10, 3)), 'بكره');
    });

    test('says the first of a month the way people do', () {
      expect(label(DateTime(2027, 4)), 'أول أبريل');
      expect(label(DateTime(2027, 4, 15)), '15 أبريل');
    });

    test('adds the year past the coming twelve months or before this year', () {
      expect(label(DateTime(2026, 3, 10)), '10 مارس');
      expect(label(DateTime(2027, 10)), 'أول أكتوبر');
      expect(label(DateTime(2027, 10, 2)), '2 أكتوبر 2027');
      expect(label(DateTime(2025, 12, 15)), '15 ديسمبر 2025');
    });
  });

  test('formatHp drops trailing zeros', () {
    expect(formatHp(1.5), '1.5');
    expect(formatHp(2.25), '2.25');
    expect(formatHp(3), '3');
    expect(formatHp(0.75), '0.75');
  });

  group('unitTitle', () {
    test('joins the brand, capacity and room', () {
      expect(unitTitle(l10n, testUnit()), 'شارب 1.5 حصان · الصالة');
      expect(
        unitTitle(l10n, testUnit(brand: null, room: null)),
        '1.5 حصان',
      );
      expect(
        unitTitle(l10n, testUnit(capacityHp: null, brand: null)),
        'الصالة',
      );
    });

    test('names a unit with no details', () {
      expect(
        unitTitle(l10n, testUnit(brand: null, capacityHp: null, room: null)),
        'تكييف',
      );
    });
  });

  group('newJobForLabel', () {
    test('uses the first name', () {
      expect(newJobForLabel(l10n, 'أ. كريم منصور'), 'شغلانة جديدة لكريم');
      expect(newJobForLabel(l10n, 'مدام سهير'), 'شغلانة جديدة لسهير');
    });

    test('joins ل to a name starting with ال', () {
      expect(newJobForLabel(l10n, 'السيد علي'), 'شغلانة جديدة للسيد');
    });

    test('falls back to a plain new job', () {
      expect(newJobForLabel(l10n, 'أستاذ'), 'شغلانة جديدة');
    });
  });

  group('customerReminderMessage', () {
    final finished = testJob(
      id: 'a',
      tags: [JobTag.maintenance],
      status: JobStatus.finished,
    );

    test('names the one job owed for', () {
      final message = customerReminderMessage(
        l10n,
        customerName: 'أ. كريم منصور',
        owed: [
          testSummary(finished, totalPiastres: 170000, paidPiastres: 50000),
        ],
        technicianName: 'محمود عبد الله',
      );

      expect(
        message,
        'أهلاً أ. كريم منصور، بفكّرك إن فاضل 1,200 ج.م من حساب صيانة دورية. '
        'تقدر تدفعهم كاش أو تحويل إنستاباي أو فودافون كاش. شكراً.\n'
        'محمود عبد الله',
      );
    });

    test('asks for the total of several jobs', () {
      final message = customerReminderMessage(
        l10n,
        customerName: 'مدام سهير',
        owed: [
          testSummary(finished, totalPiastres: 170000, paidPiastres: 50000),
          testSummary(testJob(id: 'b'), totalPiastres: 65000),
          testSummary(testJob(id: 'c'), totalPiastres: 10000),
        ],
        technicianName: 'محمود عبد الله',
      );

      expect(
        message,
        'أهلاً مدام سهير، بفكّرك إن فاضل 1,950 ج.م من حساب 3 شغلانات. '
        'تقدري تدفعهم كاش أو تحويل إنستاباي أو فودافون كاش. شكراً.\n'
        'محمود عبد الله',
      );
    });

    test('says two jobs the way people do', () {
      final message = customerReminderMessage(
        l10n,
        customerName: 'أ. كريم منصور',
        owed: [
          testSummary(finished, totalPiastres: 10000),
          testSummary(testJob(id: 'b'), totalPiastres: 10000),
        ],
        technicianName: 'محمود عبد الله',
      );

      expect(message, contains('فاضل 200 ج.م من حساب شغلانتين.'));
    });
  });
}
