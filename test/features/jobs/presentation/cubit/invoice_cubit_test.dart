import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/cubit/invoice_cubit.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_pdf.dart';

import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockInvoicePdf extends Mock implements InvoicePdf {}

void main() {
  late MockJobsRepository jobs;
  late MockExternalApps apps;
  late _MockInvoicePdf pdf;
  late Directory temporary;
  late StreamController<JobDetails?> details;
  final today = DateTime(2026, 10, 2, 11);
  const failure = UnexpectedFailure('disk full');
  final technicianPhone = PhoneNumber.tryParse('01002345678');

  setUpAll(() {
    registerFallbackValue(l10n);
    registerFallbackValue(testDetails());
    registerFallbackValue(DateTime(2026));
  });

  setUp(() {
    jobs = MockJobsRepository();
    apps = MockExternalApps();
    pdf = _MockInvoicePdf();
    temporary = Directory.systemTemp.createTempSync();
    details = StreamController.broadcast();
    when(() => jobs.watchJob('job-1')).thenAnswer((_) => details.stream);
    when(() => jobs.issueInvoice('job-1')).thenAnswer((_) async => const Ok(7));
  });

  tearDown(() async {
    await details.close();
    temporary.deleteSync(recursive: true);
  });

  Future<InvoiceCubit> started(JobDetails? first) async {
    final cubit = InvoiceCubit(
      jobs: jobs,
      apps: apps,
      jobId: 'job-1',
      pdf: pdf,
      sharedFiles: SharedFiles(temporary),
      clock: () => today,
    )..start();
    details.add(first);
    await pumpEventQueue();
    return cubit;
  }

  JobDetails finished({
    List<Payment> payments = const [],
    int? invoiceNumber = 7,
  }) => testDetails(
    job: testJob(status: JobStatus.finished, invoiceNumber: invoiceNumber),
    items: sampleItems,
    payments: payments,
  );

  group('loading', () {
    test('shows the invoice', () async {
      final shown = finished();
      final cubit = await started(shown);
      expect(cubit.state.status, JobDetailsStatus.ready);
      expect(cubit.state.details, shown);
      expect(cubit.state.today, today);
      await cubit.close();
    });

    test('a job never found is missing', () async {
      final cubit = await started(null);
      expect(cubit.state.status, JobDetailsStatus.missing);
      await cubit.close();
    });

    test('a job deleted while open is deleted', () async {
      final cubit = await started(finished());
      details.add(null);
      await pumpEventQueue();
      expect(cubit.state.status, JobDetailsStatus.deleted);
      await cubit.close();
    });
  });

  group('numbering', () {
    test('numbers a priced job once', () async {
      final cubit = await started(finished(invoiceNumber: null));
      details.add(finished(invoiceNumber: null));
      await pumpEventQueue();
      verify(() => jobs.issueInvoice('job-1')).called(1);
      await cubit.close();
    });

    test('leaves a numbered or unpriced job alone', () async {
      final numbered = await started(finished());
      await numbered.close();
      final unpriced = await started(testDetails());
      await unpriced.close();
      verifyNever(() => jobs.issueInvoice(any()));
    });

    test('reports a failure and tries again with the next change', () async {
      when(
        () => jobs.issueInvoice('job-1'),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(finished(invoiceNumber: null));
      expect(cubit.state.failure, failure);

      details.add(finished(invoiceNumber: null));
      await pumpEventQueue();

      verify(() => jobs.issueInvoice('job-1')).called(2);
      await cubit.close();
    });
  });

  group('recordPayment', () {
    setUp(() {
      when(
        () => jobs.recordPayment(
          'job-1',
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
        ),
      ).thenAnswer((_) async => const Ok(null));
    });

    setUpAll(() => registerFallbackValue(PaymentMethod.cash));

    test('records part of what is owed and what is left', () async {
      final cubit = await started(finished(payments: [testPayment(200)]));

      final saved = await cubit.recordPayment(
        amountPiastres: 100000,
        method: PaymentMethod.instapay,
      );

      expect(saved, isTrue);
      verify(
        () => jobs.recordPayment(
          'job-1',
          amountPiastres: 100000,
          method: PaymentMethod.instapay,
        ),
      ).called(1);
      expect(
        cubit.state.recorded,
        const RecordedPayment(
          amountPiastres: 100000,
          method: PaymentMethod.instapay,
          balancePiastres: 25000,
        ),
      );
      expect(cubit.state.isRecording, isFalse);
      await cubit.close();
    });

    test('refuses nothing or more than is owed', () async {
      final cubit = await started(finished());
      expect(
        await cubit.recordPayment(
          amountPiastres: 0,
          method: PaymentMethod.cash,
        ),
        isFalse,
      );
      expect(
        await cubit.recordPayment(
          amountPiastres: 145100,
          method: PaymentMethod.cash,
        ),
        isFalse,
      );
      verifyNever(
        () => jobs.recordPayment(
          any(),
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
        ),
      );
      await cubit.close();
    });

    test('reports a failure', () async {
      when(
        () => jobs.recordPayment(
          'job-1',
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
        ),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(finished());

      final saved = await cubit.recordPayment(
        amountPiastres: 145000,
        method: PaymentMethod.cash,
      );

      expect(saved, isFalse);
      expect(cubit.state.failure, failure);
      expect(cubit.state.recorded, isNull);
      await cubit.close();
    });
  });

  group('setPaymentPromise', () {
    test('keeps the promised day at midnight, or forgets it', () async {
      when(
        () => jobs.setPaymentPromise('job-1', any()),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = await started(finished());

      await cubit.setPaymentPromise(DateTime(2026, 10, 3, 14));
      await cubit.setPaymentPromise(null);

      verify(
        () => jobs.setPaymentPromise('job-1', DateTime(2026, 10, 3)),
      ).called(1);
      verify(() => jobs.setPaymentPromise('job-1', null)).called(1);
      await cubit.close();
    });

    test('reports a failure', () async {
      when(
        () => jobs.setPaymentPromise('job-1', any()),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(finished());
      await cubit.setPaymentPromise(null);
      expect(cubit.state.failure, failure);
      await cubit.close();
    });
  });

  group('sharePdf', () {
    void buildsPdf() => when(
      () => pdf.build(
        any(),
        details: any(named: 'details'),
        technicianName: any(named: 'technicianName'),
        technicianPhone: any(named: 'technicianPhone'),
        issuedOn: any(named: 'issuedOn'),
        place: any(named: 'place'),
      ),
    ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));

    Future<void> share(InvoiceCubit cubit) => cubit.sharePdf(
      l10n,
      technicianName: 'محمود عبد الله',
      technicianPhone: technicianPhone,
      place: '12 شارع الأهرام',
    );

    test('writes the PDF and shares it by its number', () async {
      buildsPdf();
      when(
        () => apps.shareFile(any(), name: any(named: 'name')),
      ).thenAnswer((_) async => true);
      final shown = finished();
      final cubit = await started(shown);

      await share(cubit);

      verify(
        () => pdf.build(
          l10n,
          details: shown,
          technicianName: 'محمود عبد الله',
          technicianPhone: technicianPhone,
          issuedOn: today,
          place: '12 شارع الأهرام',
        ),
      ).called(1);
      final path =
          verify(
                () => apps.shareFile(
                  captureAny(),
                  name: l10n.invoicePdfName('0007'),
                ),
              ).captured.single
              as String;
      expect(File(path).readAsBytesSync(), [1, 2, 3]);
      expect(cubit.state.isSharing, isFalse);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('says so when nothing could share it', () async {
      buildsPdf();
      when(
        () => apps.shareFile(any(), name: any(named: 'name')),
      ).thenAnswer((_) async => false);
      final cubit = await started(finished());

      await share(cubit);

      expect(cubit.state.failure, const InvoicePdfFailure());
      await cubit.close();
    });

    test('says so when the PDF could not be made', () async {
      when(
        () => pdf.build(
          any(),
          details: any(named: 'details'),
          technicianName: any(named: 'technicianName'),
          technicianPhone: any(named: 'technicianPhone'),
          issuedOn: any(named: 'issuedOn'),
          place: any(named: 'place'),
        ),
      ).thenThrow(const FileSystemException('no space'));
      final cubit = await started(finished());

      await share(cubit);

      expect(cubit.state.failure, const InvoicePdfFailure());
      expect(cubit.state.isSharing, isFalse);
      verifyNever(() => apps.shareFile(any(), name: any(named: 'name')));
      await cubit.close();
    });
  });
}
