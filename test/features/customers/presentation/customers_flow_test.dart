import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/pages/customer_form_page.dart';
import 'package:salahly/features/customers/presentation/pages/customer_page.dart';
import 'package:salahly/features/customers/presentation/pages/customers_page.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/pages/invoice_page.dart';

import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
  });

  T value<T>(Result<T> result) => (result as Ok<T>).value;

  /// Saves a customer straight into the database.
  Future<Customer> addCustomer(
    WidgetTester tester,
    TechnicianApp app, {
    String name = 'أ. كريم منصور',
    String? phone = '01228703314',
    String? areaId,
  }) async {
    final customer = await tester.runAsync(
      () async => value(
        await app.customers.addCustomer(
          CustomerDraft(
            name: name,
            phone: phone == null ? null : PhoneNumber.tryParse(phone),
            areaId: areaId,
          ),
        ),
      ),
    );
    await app.settle(tester);
    return customer!;
  }

  /// A cleaning for [customerId] that is done and costs [totalPiastres], of
  /// which [paidPiastres] was paid.
  Future<String> finishedJob(
    WidgetTester tester,
    TechnicianApp app,
    String customerId, {
    required int totalPiastres,
    int paidPiastres = 0,
  }) async {
    final id = await tester.runAsync(() async {
      final id = value(
        await app.jobs.createJob(
          JobDraft(customerId: customerId, tags: const [JobTag.cleaning]),
        ),
      );
      value(
        await app.jobs.saveQuote(
          id,
          items: [
            JobItemDraft(title: 'تنظيف', unitPricePiastres: totalPiastres),
          ],
          validDays: 7,
          status: QuoteStatus.none,
        ),
      );
      for (var step = 0; step < 3; step++) {
        value(await app.jobs.advance(id));
      }
      if (paidPiastres > 0) {
        value(
          await app.jobs.recordPayment(
            id,
            amountPiastres: paidPiastres,
            method: PaymentMethod.cash,
          ),
        );
      }
      return id;
    });
    await app.settle(tester);
    return id!;
  }

  Future<CustomerRecord?> stored(
    WidgetTester tester,
    TechnicianApp app,
    String id,
  ) => tester.runAsync<CustomerRecord?>(
    () => app.customers.watchCustomer(id).first,
  );

  Future<void> openCustomersTab(WidgetTester tester, TechnicianApp app) async {
    await app.pump(tester);
    await tester.tap(find.text(l10n.navCustomers).last);
    await app.settle(tester);
  }

  Future<void> tapVisible(
    WidgetTester tester,
    TechnicianApp app,
    Finder finder,
  ) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await app.settle(tester);
  }

  Finder formField(int index) => find.byType(TextFormField).at(index);

  group('adding a customer', () {
    testTechnicianApp('by hand ends on their page and in the list', (
      tester,
      app,
    ) async {
      await openCustomersTab(tester, app);
      expect(find.text(l10n.customersEmptyTitle), findsOneWidget);

      await tester.tap(find.text(l10n.customersAdd));
      await app.settle(tester);
      await tester.enterText(formField(0), 'أ. كريم منصور');
      await tester.enterText(formField(1), '01228703314');
      await tester.tap(find.text(l10n.customerSave));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerPage), findsOneWidget);
      expect(find.text('أ. كريم منصور'), findsOneWidget);
      expect(find.text('0122 870 3314'), findsOneWidget);
      final saved = await tester.runAsync(
        () => app.customers.findByPhone(PhoneNumber.tryParse('01228703314')!),
      );
      expect(saved?.name, 'أ. كريم منصور');
      expect(saved?.source, CustomerSource.manual);

      await tester.tap(find.byTooltip(l10n.back));
      await app.settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(CustomersPage), findsOneWidget);
      expect(find.text('العملاء 1', findRichText: true), findsOneWidget);
    });

    testTechnicianApp('from the contacts keeps where they came from', (
      tester,
      app,
    ) async {
      when(app.contacts.pickPhoneNumber).thenAnswer(
        (_) async => (name: 'Karim  Mansour', phone: '+20 122 870 3314'),
      );
      await openCustomersTab(tester, app);

      await tester.tap(find.text(l10n.customersEmptyContacts));
      await app.settle(tester);
      expect(find.text('Karim Mansour'), findsOneWidget);
      expect(find.text('01228703314'), findsOneWidget);
      await tester.tap(find.text(l10n.customerSave));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerPage), findsOneWidget);
      final saved = await tester.runAsync(
        () => app.customers.findByPhone(PhoneNumber.tryParse('01228703314')!),
      );
      expect(saved?.name, 'Karim Mansour');
      expect(saved?.source, CustomerSource.contacts);
    });

    testTechnicianApp('from a contact who is already a customer opens them', (
      tester,
      app,
    ) async {
      final karim = await addCustomer(tester, app);
      when(app.contacts.pickPhoneNumber).thenAnswer(
        (_) async => (name: 'كريم', phone: '+201228703314'),
      );
      await app.pump(tester);

      final opened = app
          .router(tester)
          .push<Customer>(
            AppRoutes.newCustomerFromContacts,
          );
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect((await opened)?.id, karim.id);
      expect(find.byType(CustomerFormPage), findsNothing);
      final summaries = await tester.runAsync(
        () => app.customers.watchCustomers(today: DateTime(2026, 10, 2)).first,
      );
      expect(summaries!.map((summary) => summary.customer.id), [karim.id]);
    });

    testTechnicianApp('with a number already saved offers that customer', (
      tester,
      app,
    ) async {
      final karim = await addCustomer(tester, app);
      await openCustomersTab(tester, app);

      await tester.tap(find.text(l10n.customersAdd));
      await app.settle(tester);
      await tester.enterText(formField(0), 'م. شريف عادل');
      await tester.enterText(formField(1), '0122 870 3314');
      await tester.tap(find.text(l10n.customerSave));
      await app.settle(tester);

      expect(find.text(l10n.customerExists('أ. كريم منصور')), findsOneWidget);
      await tester.tap(find.text(l10n.customerOpen));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerPage), findsOneWidget);
      expect(
        tester.widget<CustomerPage>(find.byType(CustomerPage)).customerId,
        karim.id,
      );
    });

    testTechnicianApp('hands the saved customer to the screen that asked', (
      tester,
      app,
    ) async {
      await app.pump(tester);

      final added = app.router(tester).push<Customer>(AppRoutes.newCustomer);
      await app.settle(tester);
      await tester.enterText(formField(0), 'مدام سهير عبد الله');
      await tester.tap(find.text(l10n.customerSave));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect((await added)?.name, 'مدام سهير عبد الله');
      expect(find.byType(CustomerFormPage), findsNothing);

      final cancelled = app
          .router(tester)
          .push<Customer>(
            AppRoutes.newCustomer,
          );
      await app.settle(tester);
      await tester.tap(find.byTooltip(l10n.back));
      await app.settle(tester);
      expect(await cancelled, isNull);
    });
  });

  group("a customer's page", () {
    testTechnicianApp('adds an air conditioner', (tester, app) async {
      final karim = await addCustomer(tester, app);
      await app.pump(tester, location: AppRoutes.customer(karim.id));

      await tapVisible(tester, app, find.text(l10n.unitAdd));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'شارب');
      await tester.tap(find.text(l10n.unitHp('1.5')));
      await tester.enterText(find.byType(TextField).at(1), 'الصالة');
      await tester.ensureVisible(find.text(l10n.unitSave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.unitSave));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('شارب 1.5 حصان · الصالة'), findsOneWidget);
      expect((await stored(tester, app, karim.id))!.units, [
        isA<CustomerUnit>()
            .having((unit) => unit.brand, 'brand', 'شارب')
            .having((unit) => unit.capacityHp, 'capacity', 1.5)
            .having((unit) => unit.room, 'room', 'الصالة'),
      ]);
    });

    testTechnicianApp('reminds who owes and opens the invoice to record', (
      tester,
      app,
    ) async {
      final karim = await addCustomer(tester, app);
      final jobId = await finishedJob(
        tester,
        app,
        karim.id,
        totalPiastres: 170000,
        paidPiastres: 50000,
      );
      await app.pump(tester, location: AppRoutes.customer(karim.id));

      expect(tester.takeException(), isNull);
      expect(find.textContaining('1,200', findRichText: true), findsWidgets);
      expect(find.text(l10n.customerPaidOf('male', '500', '1,700')), findsOne);

      await tapVisible(tester, app, find.text(l10n.remindCustomer));
      verify(
        () => app.apps.whatsApp(
          text: any(
            named: 'text',
            that: allOf(contains('أ. كريم منصور'), contains('1,200')),
          ),
          to: PhoneNumber.tryParse('01228703314'),
        ),
      ).called(1);

      await tapVisible(tester, app, find.text(l10n.customerRecordPayment));
      await tester.pumpAndSettle();
      expect(find.byType(InvoicePage), findsOneWidget);
      expect(
        tester.widget<InvoicePage>(find.byType(InvoicePage)).jobId,
        jobId,
      );
    });

    testTechnicianApp('saves changes to the customer', (tester, app) async {
      final karim = await addCustomer(tester, app);
      await app.pump(tester, location: AppRoutes.customer(karim.id));

      await tester.tap(find.text(l10n.customerEdit));
      await app.settle(tester);
      await tester.enterText(formField(0), 'أ. كريم منصور الشريف');
      await tester.enterText(formField(2), '7 شارع الحجاز');
      await tester.tap(find.text(l10n.customerSave));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomerFormPage), findsNothing);
      expect(find.text('أ. كريم منصور الشريف'), findsOneWidget);
      expect(find.text('7 شارع الحجاز'), findsOneWidget);
      final record = await stored(tester, app, karim.id);
      expect(record!.customer.name, 'أ. كريم منصور الشريف');
      expect(record.customer.address, '7 شارع الحجاز');
    });

    testTechnicianApp('deletes the customer with their jobs', (
      tester,
      app,
    ) async {
      final karim = await addCustomer(tester, app);
      await finishedJob(tester, app, karim.id, totalPiastres: 50000);
      await app.pump(tester, location: AppRoutes.customer(karim.id));

      await tester.tap(find.text(l10n.customerEdit));
      await app.settle(tester);
      await tapVisible(tester, app, find.text(l10n.customerDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.customerDeleteConfirm));
      await app.settle(tester);
      await tester.pumpAndSettle();

      expect(find.byType(CustomersPage), findsOneWidget);
      expect(find.byType(CustomerPage), findsNothing);
      expect(find.text(l10n.customersEmptyTitle), findsOneWidget);
      expect(await stored(tester, app, karim.id), isNull);
      final jobs = await tester.runAsync(
        () => app.jobs.watchCustomerJobs(karim.id).first,
      );
      expect(jobs, isEmpty);
    });
  });

  testTechnicianApp('the list finds customers and keeps who owes', (
    tester,
    app,
  ) async {
    final karim = await addCustomer(tester, app, areaId: 'heliopolis');
    await addCustomer(
      tester,
      app,
      name: 'مدام سهير عبد الله',
      phone: '01001234567',
      areaId: 'nasr_city',
    );
    await finishedJob(tester, app, karim.id, totalPiastres: 120000);
    await openCustomersTab(tester, app);

    expect(tester.takeException(), isNull);
    expect(find.text('العملاء 2', findRichText: true), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'مدينه نصر');
    await tester.pump();
    expect(find.text('مدام سهير عبد الله'), findsOneWidget);
    expect(find.text('أ. كريم منصور'), findsNothing);

    await tester.enterText(find.byType(TextField), '0122 870');
    await tester.pump();
    expect(find.text('أ. كريم منصور'), findsOneWidget);
    expect(find.text('مدام سهير عبد الله'), findsNothing);

    await tester.tap(find.byTooltip(l10n.customersSearchClear));
    await tester.pump();
    await tester.tap(find.text(l10n.customersFilterOwing(1)));
    await tester.pump();
    expect(find.text('أ. كريم منصور'), findsOneWidget);
    expect(find.text('مدام سهير عبد الله'), findsNothing);

    await tester.tap(find.text('أ. كريم منصور'));
    await app.settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerPage), findsOneWidget);
  });
}
