import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_message.dart';

import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  final phone = PhoneNumber.tryParse('01002345678');

  String message({
    List<Payment> payments = const [],
    int? invoiceNumber = 127,
    String customerName = 'م. شريف عادل',
  }) => invoiceMessage(
    l10n,
    details: testDetails(
      job: testJob(status: JobStatus.finished, invoiceNumber: invoiceNumber),
      customer: testCustomer(name: customerName),
      items: sampleItems,
      payments: payments,
    ),
    technicianName: 'محمود السيد',
    technicianPhone: phone,
  );

  test('asks for what is owed and how it can be paid', () {
    expect(
      message(),
      'أهلاً م. شريف عادل، دي فاتورة رقم 0127:\n'
      '• تركيب وحدة سبليت 2.25 حصان: 900 ج.م\n'
      '• ماسورة نحاس زيادة (المتر) × 4: 400 ج.م\n'
      '• حامل للوحدة الخارجية: 150 ج.م\n'
      'الإجمالي: 1,450 ج.م\n'
      'تقدر تدفع كاش أو تحويل إنستاباي أو فودافون كاش.\n'
      '\n'
      'محمود السيد · فني صيانة\n'
      '\u20660100 234 5678\u2069',
    );
  });

  test('after part is paid, says what was paid and what is left', () {
    final text = message(payments: [testPayment(1000)]);
    expect(text, contains('اتدفع: 1,000 ج.م\nالباقي: 450 ج.م\n'));
  });

  test('thanks a customer who paid it all', () {
    final text = message(
      payments: [testPayment(1450)],
      customerName: 'مدام سهير',
    );
    expect(text, contains('اتدفعت كلها، شكراً ليكي.'));
    expect(text, isNot(contains('الباقي')));
  });

  test('speaks to a woman as one when money is owed', () {
    expect(
      message(customerName: 'مدام سهير'),
      contains('تقدري تدفعي كاش'),
    );
  });

  test('leaves the number out until there is one', () {
    expect(
      message(invoiceNumber: null),
      startsWith('أهلاً م. شريف عادل، دي الفاتورة:\n'),
    );
  });

  test('names the payment methods and pads invoice numbers', () {
    expect(
      PaymentMethod.values.map((method) => paymentMethodLabel(l10n, method)),
      ['كاش', 'إنستاباي', 'فودافون كاش', 'تاني'],
    );
    expect(invoiceNumberLabel(7), '0007');
    expect(invoiceNumberLabel(12345), '12345');
  });
}
