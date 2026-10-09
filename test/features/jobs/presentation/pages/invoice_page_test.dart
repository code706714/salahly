import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/cubit/invoice_cubit.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_message.dart';
import 'package:salahly/features/jobs/presentation/pages/invoice_page.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockInvoiceCubit extends MockCubit<InvoiceState>
    implements InvoiceCubit {}

void main() {
  late _MockInvoiceCubit cubit;
  late MockSessionCubit session;
  late MockAreasCubit areas;
  late MockExternalApps apps;
  final today = DateTime(2026, 10, 2, 11);
  final phone = PhoneNumber.tryParse('01002345678')!;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(phone);
    registerFallbackValue(l10n);
    registerFallbackValue(PaymentMethod.cash);
  });

  setUp(() {
    cubit = _MockInvoiceCubit();
    session = MockSessionCubit();
    areas = MockAreasCubit();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(
      const SessionReady(
        user: TechnicianApp.user,
        profile: TechnicianApp.profile,
      ),
    );
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(
      () => cubit.recordPayment(
        amountPiastres: any(named: 'amountPiastres'),
        method: any(named: 'method'),
      ),
    ).thenAnswer((_) async => true);
    when(() => cubit.setPaymentPromise(any())).thenAnswer((_) async {});
    when(
      () => cubit.sharePdf(
        any(),
        technicianName: any(named: 'technicianName'),
        technicianPhone: any(named: 'technicianPhone'),
        place: any(named: 'place'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
  });

  JobDetails finished({
    List<Payment> payments = const [],
    int? invoiceNumber = 127,
    QuoteStatus quoteStatus = QuoteStatus.sent,
    DateTime? paymentPromisedOn,
    bool priced = true,
  }) => testDetails(
    job: testJob(
      status: JobStatus.finished,
      invoiceNumber: invoiceNumber,
      quoteStatus: quoteStatus,
      paymentPromisedOn: paymentPromisedOn,
    ),
    items: priced ? sampleItems : const [],
    payments: payments,
  );

  InvoiceState ready(JobDetails details) => InvoiceState(
    today: today,
    status: JobDetailsStatus.ready,
    details: details,
  );

  void show(InvoiceState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const InvoiceView(),
    repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
    blocs: [
      BlocProvider<InvoiceCubit>.value(value: cubit),
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<AreasCubit>.value(value: areas),
    ],
    stubRoutes: [AppRoutes.jobQuote('job-1'), AppRoutes.technicianMoney],
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.byType(TextField);

  group('states', () {
    testWidgets('shows nothing while loading', (tester) async {
      show(InvoiceState(today: today));
      await pumpPage(tester);
      expect(find.text(l10n.invoiceTitleUnnumbered), findsNothing);
    });

    testWidgets('shows nothing while signing out', (tester) async {
      when(() => session.state).thenReturn(const SessionSignedOut());
      show(ready(finished()));
      await pumpPage(tester);
      expect(find.text(l10n.invoiceTitle('0127')), findsNothing);
    });

    testWidgets('says when the consumer declined the price change', (
      tester,
    ) async {
      show(ready(finished(quoteStatus: QuoteStatus.declined)));
      await pumpPage(tester);
      expect(
        find.text('م. شريف عادل · ${l10n.platformJobQuoteDeclined}'),
        findsOneWidget,
      );
    });

    testWidgets('says when the job is not on this phone', (tester) async {
      show(InvoiceState(today: today, status: JobDetailsStatus.missing));
      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.invoiceTitleUnnumbered), findsOneWidget);
      expect(find.text(l10n.jobPageMissing), findsOneWidget);
    });

    testWidgets('shows the invoice and asks for the money', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.invoiceTitle('0127')), findsOneWidget);
      expect(
        find.text('م. شريف عادل · ${l10n.invoiceFromQuote}'),
        findsOneWidget,
      );
      expect(find.text(l10n.invoicePdf), findsOneWidget);
      expect(
        find.text(l10n.invoiceSignature('محمود عبد الله')),
        findsOneWidget,
      );
      expect(find.text('0100 234 5678'), findsOneWidget);
      expect(find.text('2 أكتوبر 2026'), findsOneWidget);
      expect(find.text('ماسورة نحاس زيادة (المتر) × 4'), findsOneWidget);
      expect(find.text(l10n.pounds('1,450')), findsNWidgets(2));
      expect(find.text(l10n.invoiceRecord('1,450')), findsOneWidget);

      await scrollTo(tester, find.text(l10n.invoiceSend));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.invoiceRecordTitle), findsOneWidget);
      expect(find.text(l10n.paymentMethodVodafoneCash), findsOneWidget);
      expect(find.text(l10n.invoicePromiseTitle), findsOneWidget);
    });

    testWidgets('an invoice without a number or a sent quote', (
      tester,
    ) async {
      show(
        ready(finished(invoiceNumber: null, quoteStatus: QuoteStatus.draft)),
      );
      await pumpPage(tester);
      expect(find.text(l10n.invoiceTitleUnnumbered), findsOneWidget);
      expect(find.text('م. شريف عادل'), findsOneWidget);
    });

    testWidgets('lists the money received', (tester) async {
      show(
        ready(
          finished(
            payments: [
              testPayment(1000, method: PaymentMethod.instapay),
            ],
          ),
        ),
      );
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoicePayments));

      expect(
        find.text(
          l10n.invoicePaymentLine(
            l10n.paymentMethodInstapay,
            weekdayDate(DateTime(2026, 10, 2)),
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.invoiceRecord('450')), findsOneWidget);
    });

    testWidgets('a paid invoice says so and leads to the money', (
      tester,
    ) async {
      show(ready(finished(payments: [testPayment(1450)])));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoiceSettled));

      expect(find.text(l10n.invoiceRecordTitle), findsNothing);
      expect(find.text(l10n.invoicePromiseTitle), findsNothing);
      await tester.tap(find.text(l10n.invoiceSeeMoney));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.technicianMoney), findsOneWidget);
    });

    testWidgets('a job without a price leads to its quote', (tester) async {
      show(ready(finished(priced: false, invoiceNumber: null)));
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.invoiceNeedsPrice), findsOneWidget);
      expect(find.text(l10n.invoicePdf), findsNothing);
      expect(find.text(l10n.invoiceSend), findsNothing);
      await tester.tap(find.text(l10n.invoiceWriteQuote));
      await tester.pumpAndSettle();
      expect(find.text(AppRoutes.jobQuote('job-1')), findsOneWidget);
    });

    testWidgets('shows the PDF being made', (tester) async {
      show(ready(finished()).copyWith(isSharing: true));
      await pumpPage(tester);
      expect(find.text(l10n.invoicePdf), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says why an action failed', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          ready(finished()).copyWith(failure: () => const NetworkFailure()),
        ),
        initialState: ready(finished()),
      );
      await pumpPage(tester);
      await tester.pump();
      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });

    testWidgets('says the PDF could not be shared', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          ready(finished()).copyWith(failure: () => const InvoicePdfFailure()),
        ),
        initialState: ready(finished()),
      );
      await pumpPage(tester);
      await tester.pump();
      expect(find.text(l10n.invoicePdfFailed), findsOneWidget);
    });
  });

  group('recording money', () {
    testWidgets('records all of what is owed in cash', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.invoiceRecord('1,450')));
      await tester.pump();

      verify(
        () => cubit.recordPayment(
          amountPiastres: 145000,
          method: PaymentMethod.cash,
        ),
      ).called(1);
    });

    testWidgets('records part of it by another way', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.paymentMethodOther));

      await tester.tap(find.text(l10n.invoicePartAmount));
      await tester.pump();
      expect(find.text(l10n.invoiceRecordEmpty), findsOneWidget);
      await tester.tap(find.text(l10n.invoiceRecordEmpty));
      await tester.enterText(amountField(), '1000');
      await tester.tap(find.text(l10n.paymentMethodInstapay));
      await tester.pump();
      await tester.tap(find.text(l10n.invoiceRecord('1,000')));
      await tester.pump();

      verify(
        () => cubit.recordPayment(
          amountPiastres: 100000,
          method: PaymentMethod.instapay,
        ),
      ).called(1);
    });

    testWidgets('refuses more than is owed', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoicePartAmount));

      await tester.tap(find.text(l10n.invoicePartAmount));
      await tester.enterText(amountField(), '2000');
      await tester.pump();

      expect(find.text(l10n.invoiceAmountTooHigh('1,450')), findsOneWidget);
      await tester.tap(find.text(l10n.invoiceRecordEmpty));
      verifyNever(
        () => cubit.recordPayment(
          amountPiastres: any(named: 'amountPiastres'),
          method: any(named: 'method'),
        ),
      );
    });

    testWidgets('goes back to all of it', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoicePartAmount));

      await tester.tap(find.text(l10n.invoicePartAmount));
      await tester.enterText(amountField(), '500');
      await tester.pump();
      expect(find.text(l10n.invoiceRecord('500')), findsOneWidget);
      await tester.tap(find.text(l10n.invoiceFullAmount));
      await tester.pump();

      expect(find.text('1,450'), findsOneWidget);
      expect(find.text(l10n.invoiceRecord('1,450')), findsOneWidget);
    });

    testWidgets('says what was recorded and what is left', (tester) async {
      show(
        ready(finished(payments: [testPayment(1000)])).copyWith(
          recorded: () => const RecordedPayment(
            amountPiastres: 100000,
            method: PaymentMethod.cash,
            balancePiastres: 45000,
          ),
        ),
      );
      await pumpPage(tester);
      await scrollTo(
        tester,
        find.text(
          l10n.invoiceRecordedPart('1,000', l10n.paymentMethodCash, '450'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.invoiceRecordTitle), findsNothing);
      expect(find.text(l10n.invoiceSeeMoney), findsOneWidget);
    });

    testWidgets('says when it was all paid', (tester) async {
      show(
        ready(finished(payments: [testPayment(1450)])).copyWith(
          recorded: () => const RecordedPayment(
            amountPiastres: 145000,
            method: PaymentMethod.vodafoneCash,
            balancePiastres: 0,
          ),
        ),
      );
      await pumpPage(tester);
      await scrollTo(
        tester,
        find.text(l10n.invoiceRecordedAll(l10n.paymentMethodVodafoneCash)),
      );
      expect(find.text(l10n.invoiceSettled), findsNothing);
    });
  });

  group('promise', () {
    Future<void> pickDay(WidgetTester tester, {String? day}) async {
      await tester.pumpAndSettle();
      if (day != null) {
        await tester.tap(find.text(day));
        await tester.pump();
      }
      final ok = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).okButtonLabel;
      await tester.tap(find.text(ok));
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the day the customer promised to pay', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoicePromisePick));

      await tester.tap(find.text(l10n.invoicePromisePick));
      await pickDay(tester);

      verify(() => cubit.setPaymentPromise(DateTime(2026, 10, 3))).called(1);
    });

    testWidgets('changes or clears a promise', (tester) async {
      show(ready(finished(paymentPromisedOn: DateTime(2026, 10, 3))));
      await pumpPage(tester);
      final promise = l10n.duePromised(l10n.tomorrow);
      await scrollTo(tester, find.text(promise));

      await tester.tap(find.text(l10n.invoicePromiseChange));
      await pickDay(tester, day: '5');
      verify(() => cubit.setPaymentPromise(DateTime(2026, 10, 5))).called(1);

      await tester.tap(find.byTooltip(l10n.invoicePromiseClear));
      verify(() => cubit.setPaymentPromise(null)).called(1);
    });

    testWidgets('keeps the promise when the picker is closed', (
      tester,
    ) async {
      show(ready(finished()));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoicePromisePick));

      await tester.tap(find.text(l10n.invoicePromisePick));
      await tester.pumpAndSettle();
      final cancel = MaterialLocalizations.of(
        tester.element(find.byType(DatePickerDialog)),
      ).cancelButtonLabel;
      await tester.tap(find.text(cancel));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.setPaymentPromise(any()));
    });
  });

  group('sharing', () {
    testWidgets('sends the invoice on WhatsApp', (tester) async {
      final details = finished();
      show(ready(details));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.invoiceSend));

      await tester.tap(find.text(l10n.invoiceSend));
      await tester.pump();

      verify(
        () => apps.whatsApp(
          text: invoiceMessage(
            l10n,
            details: details,
            technicianName: 'محمود عبد الله',
            technicianPhone: phone,
          ),
          to: phone,
        ),
      ).called(1);
    });

    testWidgets('shares the invoice as a PDF', (tester) async {
      show(ready(finished()));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.invoicePdf));
      await tester.pump();

      verify(
        () => cubit.sharePdf(
          any(),
          technicianName: 'محمود عبد الله',
          technicianPhone: phone,
          place: '12 شارع الأهرام، مصر الجديدة',
        ),
      ).called(1);
    });

    testWidgets('a customer without an address has no place on it', (
      tester,
    ) async {
      show(
        ready(
          testDetails(
            job: testJob(status: JobStatus.finished, invoiceNumber: 1),
            customer: testCustomer(areaId: null, address: null),
            items: sampleItems,
          ),
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.invoicePdf));
      await tester.pump();

      verify(
        () => cubit.sharePdf(
          any(),
          technicianName: any(named: 'technicianName'),
          technicianPhone: any(named: 'technicianPhone'),
        ),
      ).called(1);
    });
  });
}
