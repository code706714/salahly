import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';

import '../../../../helpers/job_fixtures.dart';

void main() {
  final today = DateTime(2026, 10, 2, 15);

  Job finished(DateTime finishedAt, {DateTime? promised}) => testJob(
    status: JobStatus.finished,
    finishedAt: finishedAt,
    paymentPromisedOn: promised,
  );

  group('PaymentDue.of', () {
    test('is due today when finished today', () {
      expect(
        PaymentDue.of(finished(DateTime(2026, 10, 2, 9)), today: today),
        const PaymentDueToday(),
      );
    });

    test('counts calendar days late since the job was finished', () {
      expect(
        PaymentDue.of(finished(DateTime(2026, 9, 20, 23)), today: today),
        const PaymentLate(12),
      );
    });

    test('waits for a promise that is still ahead', () {
      expect(
        PaymentDue.of(
          finished(DateTime(2026, 9, 20), promised: DateTime(2026, 10, 4)),
          today: today,
        ),
        PaymentPromised(DateTime(2026, 10, 4)),
      );
    });

    test('a promise for today is still a promise', () {
      expect(
        PaymentDue.of(
          finished(DateTime(2026, 9, 20), promised: DateTime(2026, 10, 2)),
          today: today,
        ),
        PaymentPromised(DateTime(2026, 10, 2)),
      );
    });

    test('counts late days from a broken promise', () {
      final due = PaymentDue.of(
        finished(DateTime(2026, 9, 20), promised: DateTime(2026, 9, 29)),
        today: today,
      );

      expect(due, const PaymentLate(3));
      expect(due.daysLate, 3);
    });
  });
}
