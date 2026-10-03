import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_pdf.dart';

import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => initializeDateFormatting('ar'));

  test('builds an A4 PDF in the bundled Arabic font', () async {
    final bytes = await const InvoicePdf().build(
      l10n,
      details: testDetails(
        job: testJob(status: JobStatus.finished, invoiceNumber: 127),
        items: sampleItems,
        payments: [testPayment(1000)],
      ),
      technicianName: 'محمود السيد',
      technicianPhone: PhoneNumber.tryParse('01002345678'),
      issuedOn: DateTime(2026, 10, 2),
      place: '12 شارع الأهرام، مصر الجديدة',
    );

    expect(bytes.length, greaterThan(1000));
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF-'));
    expect(text, contains('/MediaBox[0 0 595.27559 841.88976]'));
    expect(text, contains('IBMPlexSansArabic'));
  });

  test('builds one for a job without a number, payments or place', () async {
    final bytes = await const InvoicePdf().build(
      l10n,
      details: testDetails(items: sampleItems.take(1).toList()),
      technicianName: 'محمود السيد',
      technicianPhone: null,
      issuedOn: DateTime(2026, 10, 2),
    );

    expect(latin1.decode(bytes), startsWith('%PDF-'));
  });
}
