import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/contacts/contact_picker.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/pages/technician_account_page.dart';
import 'package:salahly/features/balance/presentation/pages/balance_page.dart';
import 'package:salahly/features/balance/presentation/pages/buy_uses_page.dart';
import 'package:salahly/features/customers/presentation/pages/customer_form_page.dart';
import 'package:salahly/features/customers/presentation/pages/customer_page.dart';
import 'package:salahly/features/customers/presentation/pages/customers_page.dart';
import 'package:salahly/features/home/presentation/pages/today_page.dart';
import 'package:salahly/features/jobs/presentation/pages/calendar_page.dart';
import 'package:salahly/features/jobs/presentation/pages/invoice_page.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/jobs_page.dart';
import 'package:salahly/features/jobs/presentation/pages/new_job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/quote_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_requests_page.dart';
import 'package:salahly/features/money/presentation/pages/money_page.dart';

import '../../helpers/customer_fixtures.dart';
import '../../helpers/technician_app.dart';
import '../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    TechnicianApp.registerFallbacks();
  });

  testTechnicianApp('a signed-in technician lands on today', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    expect(find.byType(TodayPage), findsOneWidget);
    expect(find.text(l10n.navJobs), findsOneWidget);
  });

  testTechnicianApp('the tabs switch between the four main screens', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    for (final (label, page) in [
      (l10n.navJobs, JobsPage),
      (l10n.navCustomers, CustomersPage),
      (l10n.navMoney, MoneyPage),
      (l10n.navToday, TodayPage),
    ]) {
      await tester.tap(find.text(label).last);
      await app.settle(tester);
      expect(find.byType(page), findsOneWidget, reason: label);
    }
  });

  group('screens pushed over the tabs', () {
    for (final (location, page) in [
      (AppRoutes.technicianAccount, TechnicianAccountPage),
      (AppRoutes.incomingRequests, IncomingRequestsPage),
      (AppRoutes.incomingRequest('request-1'), IncomingRequestPage),
      (AppRoutes.technicianCalendar, CalendarPage),
      (AppRoutes.newJob, NewJobPage),
      (AppRoutes.job('job-1'), JobPage),
      (AppRoutes.jobQuote('job-1'), QuotePage),
      (AppRoutes.jobInvoice('job-1'), InvoicePage),
      (AppRoutes.newCustomer, CustomerFormPage),
      (AppRoutes.customer('customer-1'), CustomerPage),
      (AppRoutes.editCustomer('customer-1'), CustomerFormPage),
      (AppRoutes.technicianBalance, BalancePage),
      (AppRoutes.technicianBuyUses, BuyUsesPage),
    ]) {
      testTechnicianApp('$location opens $page without the tabs', (
        tester,
        app,
      ) async {
        await app.pump(tester);
        // Customer screens close when their customer does not exist.
        await seedCustomer(tester, app);

        unawaited(app.router(tester).push(location));
        await app.settle(tester);

        expect(find.byType(page), findsOneWidget);
        expect(find.text(l10n.navJobs), findsNothing);
      });
    }
  });

  testTechnicianApp('passes the customer of a new job and the contacts flag', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    unawaited(app.router(tester).push(AppRoutes.newJobFor('customer-7')));
    await app.settle(tester);
    expect(
      tester.widget<NewJobPage>(find.byType(NewJobPage)).customerId,
      'customer-7',
    );

    // The contact picker stays open, so the form does too.
    when(
      app.contacts.pickPhoneNumber,
    ).thenAnswer((_) => Completer<PickedContact?>().future);
    unawaited(app.router(tester).push(AppRoutes.newCustomerFromContacts));
    await app.settle(tester);
    expect(
      tester
          .widget<CustomerFormPage>(find.byType(CustomerFormPage))
          .fromContacts,
      isTrue,
    );
  });

  testTechnicianApp('opens the balance and buying for a technician', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    unawaited(
      app.router(tester).push(AppRoutes.balanceFor(UserRole.technician)),
    );
    await app.settle(tester);
    expect(
      tester.widget<BalancePage>(find.byType(BalancePage)).role,
      UserRole.technician,
    );

    unawaited(
      app.router(tester).push(AppRoutes.buyUsesFor(UserRole.technician)),
    );
    await app.settle(tester);
    expect(
      tester.widget<BuyUsesPage>(find.byType(BuyUsesPage)).role,
      UserRole.technician,
    );
  });

  for (final location in [
    AppRoutes.consumerBalance,
    AppRoutes.consumerBuyUses,
  ]) {
    testTechnicianApp('a technician cannot open $location', (
      tester,
      app,
    ) async {
      await app.pump(tester, location: location);

      expect(find.byType(TodayPage), findsOneWidget);
      expect(find.byType(BalancePage), findsNothing);
      expect(find.byType(BuyUsesPage), findsNothing);
    });
  }
}
