import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';
import 'package:salahly/features/money/presentation/cubit/money_cubit.dart';
import 'package:salahly/features/money/presentation/money_labels.dart';
import 'package:salahly/features/money/presentation/pages/money_page.dart';

import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockMoneyCubit extends MockCubit<MoneyState> implements MoneyCubit {}

const _technician = SessionReady(
  user: AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(
      verificationStatus: VerificationStatus.approved,
      jobCredits: 3,
    ),
  ),
);

void main() {
  late MockSessionCubit session;
  late _MockMoneyCubit money;
  late MockSyncCubit sync;
  late MockExternalApps apps;
  final today = DateTime(2026, 10, 2);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
  });

  setUp(() {
    session = MockSessionCubit();
    money = _MockMoneyCubit();
    sync = MockSyncCubit();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(_technician);
    when(() => sync.state).thenReturn(const SyncState());
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
  });

  const october = MonthIncome(
    jobCount: 27,
    totalPiastres: 1840000,
    collectedPiastres: 1455000,
  );

  final sohair = testSummary(
    testJob(
      id: 'sohair',
      tags: const [JobTag.installation],
      status: JobStatus.finished,
      finishedAt: DateTime(2026, 9, 20, 15),
    ),
    customerName: 'مدام سهير عبد الله',
    customerPhone: '01001112233',
    totalPiastres: 140000,
  );
  final karim = testSummary(
    testJob(
      id: 'karim',
      customerId: 'customer-2',
      tags: const [],
      description: 'صيانة تكييفين',
      status: JobStatus.finished,
      finishedAt: DateTime(2026, 9, 26, 12),
    ),
    totalPiastres: 170000,
    paidPiastres: 50000,
  );
  final walid = testSummary(
    testJob(
      id: 'walid',
      customerId: 'customer-3',
      tags: const [],
      description: 'كشف + شحن فريون',
      status: JobStatus.finished,
      finishedAt: DateTime(2026, 9, 28, 18),
      paymentPromisedOn: DateTime(2026, 10, 4),
    ),
    customerName: 'أ. وليد حسني',
    customerPhone: '01001112235',
    totalPiastres: 60000,
  );
  final hala = testSummary(
    testJob(
      id: 'hala',
      customerId: 'customer-4',
      tags: const [JobTag.cleaning, JobTag.freon],
      status: JobStatus.finished,
      finishedAt: DateTime(2026, 10, 2, 11),
    ),
    customerName: 'أ. هالة فتحي',
    customerPhone: '01001112236',
    totalPiastres: 65000,
  );

  MoneyState showing({
    DateTime? month,
    MonthIncome? income = october,
    List<JobSummary>? awaiting,
  }) {
    final state = MoneyState(
      today: today,
      month: month ?? DateTime(2026, 10),
      income: income,
      awaitingPayment: awaiting ?? [sohair, karim, walid, hala],
      firstFinishedAt: DateTime(2026, 8, 3),
    );
    when(() => money.state).thenReturn(state);
    return state;
  }

  Future<void> pumpView(WidgetTester tester, {Size size = smallPhone}) =>
      tester.pumpApp(
        const MoneyView(),
        surfaceSize: size,
        repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
        blocs: [
          BlocProvider<SessionCubit>.value(value: session),
          BlocProvider<MoneyCubit>.value(value: money),
          BlocProvider<SyncCubit>.value(value: sync),
        ],
        stubRoutes: [
          AppRoutes.job('sohair'),
          AppRoutes.jobInvoice('hala'),
        ],
      );

  Finder rich(String text) => find.textContaining(text, findRichText: true);

  group('the month', () {
    testWidgets('shows the income so far, collected and still out', (
      tester,
    ) async {
      showing();
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('أكتوبر 2026'), findsOneWidget);
      expect(find.text(l10n.moneyIncomeToDate), findsOneWidget);
      expect(rich('18,400'), findsOneWidget);
      expect(find.text(l10n.moneyFromJobs(27)), findsOneWidget);
      expect(find.text('من 27 شغلانة'), findsOneWidget);
      expect(find.text(l10n.moneyCollected), findsOneWidget);
      expect(rich('14,550'), findsOneWidget);
      expect(find.text(l10n.moneyOutstanding), findsOneWidget);
      expect(rich('3,850'), findsOneWidget);
    });

    testWidgets('names an earlier month by its name', (tester) async {
      showing(month: DateTime(2026, 9));
      await pumpView(tester);

      expect(find.text('سبتمبر 2026'), findsOneWidget);
      expect(find.text('دخل شهر سبتمبر'), findsOneWidget);
    });

    testWidgets('stays calm for a month with nothing', (tester) async {
      showing(income: MonthIncome.empty);
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.moneyFromJobs(0)), findsOneWidget);
      expect(
        find.text('0 ${l10n.currencyEgp}', findRichText: true),
        findsNWidgets(3),
      );
    });

    testWidgets('waits for the records before listing anyone', (
      tester,
    ) async {
      when(() => money.state).thenReturn(MoneyState.on(today));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.moneyIncomeToDate), findsOneWidget);
      expect(find.text(l10n.moneyOwingTitle), findsNothing);
    });

    testWidgets('picks another month from the sheet', (tester) async {
      showing();
      await pumpView(tester);

      await tester.tap(find.text('أكتوبر 2026'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.moneyMonthsTitle), findsOneWidget);
      expect(find.text('سبتمبر 2026'), findsOneWidget);
      expect(find.text('أغسطس 2026'), findsOneWidget);
      expect(find.text('يوليو 2026'), findsNothing);

      await tester.tap(find.text('سبتمبر 2026'));
      await tester.pumpAndSettle();

      verify(() => money.selectMonth(DateTime(2026, 9))).called(1);
      expect(find.text(l10n.moneyMonthsTitle), findsNothing);
    });

    testWidgets('keeps the month when the sheet is dismissed', (
      tester,
    ) async {
      showing();
      await pumpView(tester);

      await tester.tap(find.text('أكتوبر 2026'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 40));
      await tester.pumpAndSettle();

      expect(find.text(l10n.moneyMonthsTitle), findsNothing);
      verifyNever(() => money.selectMonth(any()));
    });
  });

  group('who owes', () {
    testWidgets('lists every job with its money and where it stands', (
      tester,
    ) async {
      showing();
      await pumpView(tester);

      expect(find.text(l10n.moneyOwingTitle), findsOneWidget);
      expect(find.text('4 عملاء'), findsOneWidget);
      expect(find.text('مدام سهير عبد الله'), findsOneWidget);
      expect(find.text('تركيب · 1,400 ج.م'), findsOneWidget);
      expect(find.text('متأخر 12 يوم'), findsOneWidget);
      expect(find.text('صيانة تكييفين · باقي 1,200 من 1,700'), findsOneWidget);
      expect(find.text('متأخر 6 أيام · دفع جزء'), findsOneWidget);
      expect(find.text('كشف + شحن فريون · 600 ج.م'), findsOneWidget);
      expect(find.text('وعد يدفع الأحد'), findsOneWidget);
      expect(find.text('تنظيف + شحن فريون · 650 ج.م'), findsOneWidget);
      expect(find.text(l10n.dueToday), findsOneWidget);
      expect(find.text(l10n.remindCustomerFeminine), findsOneWidget);
      expect(find.text(l10n.remindCustomer), findsNWidgets(2));
      expect(find.text(l10n.moneyRecordPayment), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.moneyRemindNote), findsOneWidget);
    });

    testWidgets('reminds a customer on WhatsApp with the polite message', (
      tester,
    ) async {
      showing();
      await pumpView(tester);

      await tester.tap(find.text(l10n.remindCustomerFeminine));
      await tester.pump();

      verify(
        () => apps.whatsApp(
          text: paymentReminderMessage(
            l10n,
            job: sohair.job,
            customerName: 'مدام سهير عبد الله',
            balancePiastres: 140000,
            technicianName: 'محمود عبد الله',
          ),
          to: PhoneNumber.tryParse('01001112233'),
        ),
      ).called(1);
    });

    testWidgets('reminds about the rest of a partly paid job', (
      tester,
    ) async {
      showing(awaiting: [karim]);
      await pumpView(tester);

      await tester.tap(find.text(l10n.remindCustomer));
      await tester.pump();

      final text =
          verify(
                () => apps.whatsApp(
                  text: captureAny(named: 'text'),
                  to: PhoneNumber.tryParse('01228703314'),
                ),
              ).captured.single
              as String;
      expect(text, contains('فاضل 1,200 ج.م من حساب صيانة تكييفين'));
      expect(text, contains('تقدر'));
    });

    testWidgets('says so when WhatsApp does not open', (tester) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => false);
      showing(awaiting: [sohair]);
      await pumpView(tester);

      await tester.tap(find.text(l10n.remindCustomerFeminine));
      await tester.pump();

      expect(find.text(l10n.whatsappFailed), findsOneWidget);
    });

    testWidgets('offers no reminder to a customer without a phone', (
      tester,
    ) async {
      showing(
        awaiting: [
          testSummary(karim.job, customerPhone: null, totalPiastres: 170000),
        ],
      );
      await pumpView(tester);

      expect(find.text('أ. كريم منصور'), findsOneWidget);
      expect(find.text(l10n.remindCustomer), findsNothing);
      expect(find.text(l10n.remindCustomerFeminine), findsNothing);
      expect(find.text(l10n.moneyRemindNote), findsNothing);
    });

    testWidgets('records money due today on the invoice', (tester) async {
      showing(awaiting: [hala]);
      await pumpView(tester);

      expect(find.text(l10n.moneyRemindNote), findsNothing);
      await tester.tap(find.text(l10n.moneyRecordPayment));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobInvoice('hala')), findsOneWidget);
    });

    testWidgets('opens a job', (tester) async {
      showing();
      await pumpView(tester);

      await tester.tap(find.text('مدام سهير عبد الله'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('sohair')), findsOneWidget);
    });

    testWidgets('marks unsent changes while offline', (tester) async {
      when(
        () => sync.state,
      ).thenReturn(const SyncState(hasNetwork: false, pendingChanges: 1));
      showing(
        awaiting: [
          testSummary(sohair.job, totalPiastres: 1000, isSynced: false),
        ],
      );
      await pumpView(tester);

      expect(find.text(l10n.jobPendingSync), findsOneWidget);
    });

    testWidgets('is calm when nobody owes anything', (tester) async {
      showing(awaiting: const []);
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.moneyNobodyOwes), findsOneWidget);
      expect(find.text(l10n.moneyNobodyOwesHint), findsOneWidget);
      expect(find.textContaining('عملاء'), findsNothing);
      expect(find.text(l10n.moneyRemindNote), findsNothing);
    });
  });

  testWidgets('shows nothing while signing out', (tester) async {
    when(() => session.state).thenReturn(const SessionSignedOut());
    showing();
    await pumpView(tester);

    expect(find.text(l10n.moneyIncomeToDate), findsNothing);
  });

  testTechnicianApp('follows the money on the phone, month by month', (
    tester,
    app,
  ) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final finishedOn = DateTime(lastMonth.year, lastMonth.month, 10, 13);
    final phone = PhoneNumber.tryParse('01001112233');
    late String jobId;
    await tester.runAsync(() async {
      app.now = finishedOn;
      final customer = ok(
        await app.customers.addCustomer(
          CustomerDraft(name: 'مدام سهير عبد الله', phone: phone),
        ),
      );
      jobId = ok(
        await app.jobs.createJob(
          JobDraft(customerId: customer.id, tags: const [JobTag.installation]),
        ),
      );
      ok(
        await app.jobs.saveQuote(
          jobId,
          items: const [
            JobItemDraft(title: 'تركيب', unitPricePiastres: 140000),
          ],
          validDays: 3,
          status: QuoteStatus.accepted,
        ),
      );
      for (var step = 0; step < 3; step++) {
        ok(await app.jobs.advance(jobId));
      }
      app.now = now;
    });
    await app.pump(tester);

    await tester.tap(find.text(l10n.navMoney).last);
    await app.settle(tester);

    expect(find.text(l10n.moneyIncomeToDate), findsOneWidget);
    expect(find.text(l10n.moneyFromJobs(0)), findsOneWidget);
    expect(find.text('مدام سهير عبد الله'), findsOneWidget);
    expect(
      find.text(l10n.dueLate(CalendarDate.daysBetween(finishedOn, now))),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.remindCustomerFeminine));
    await app.settle(tester);

    final message =
        verify(
              () => app.apps.whatsApp(
                text: captureAny(named: 'text'),
                to: phone,
              ),
            ).captured.single
            as String;
    expect(message, contains('فاضل 1,400 ج.م من حساب تركيب'));

    await tester.tap(find.text(monthYear(DateTime(now.year, now.month))));
    await app.settle(tester);
    await tester.tap(find.text(monthYear(lastMonth)));
    await app.settle(tester);

    expect(
      find.text(incomeTitle(l10n, lastMonth, today: now)),
      findsOneWidget,
    );
    expect(find.text(l10n.moneyFromJobs(1)), findsOneWidget);
    expect(
      find.text('1,400 ${l10n.currencyEgp}', findRichText: true),
      findsNWidgets(2),
    );

    await tester.runAsync(
      () async => ok(
        await app.jobs.recordPayment(
          jobId,
          amountPiastres: 140000,
          method: PaymentMethod.cash,
        ),
      ),
    );
    await app.settle(tester);

    expect(find.text(l10n.moneyNobodyOwes), findsOneWidget);
    expect(find.text('مدام سهير عبد الله'), findsNothing);
    expect(
      find.text('0 ${l10n.currencyEgp}', findRichText: true),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(() => app.jobs.watchAwaitingPayment().first),
      isEmpty,
    );
  });
}

T ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
};
