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
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_cubit.dart';
import 'package:salahly/features/customers/presentation/customer_messages.dart';
import 'package:salahly/features/customers/presentation/pages/customer_page.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockCustomerCubit extends MockCubit<CustomerState>
    implements CustomerCubit {}

void main() {
  late _MockCustomerCubit cubit;
  late MockSessionCubit session;
  late MockAreasCubit areas;
  late MockExternalApps apps;
  final today = DateTime(2026, 10, 2);
  final phone = PhoneNumber.tryParse('01228703314')!;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(phone);
    registerFallbackValue(const CustomerUnitDraft());
    registerFallbackValue(testUnit());
  });

  setUp(() {
    cubit = _MockCustomerCubit();
    session = MockSessionCubit();
    areas = MockAreasCubit();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(technicianSession);
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
    when(() => apps.dial(any())).thenAnswer((_) async => true);
    when(() => apps.map(any())).thenAnswer((_) async => true);
  });

  JobSummary job(
    String id, {
    required String title,
    required DateTime at,
    JobStatus status = JobStatus.paid,
    int total = 0,
    int paid = 0,
  }) => testSummary(
    Job(
      id: id,
      customerId: 'customer-1',
      description: title,
      scheduledAt: at,
      status: status,
      finishedAt: status.isDone ? at : null,
      createdAt: at,
      updatedAt: at,
    ),
    totalPiastres: total,
    paidPiastres: paid,
  );

  // Karim, as in the design.
  final maintenance = job(
    'maintenance',
    title: 'صيانة تكييفين',
    at: DateTime(2026, 9, 26, 13),
    status: JobStatus.finished,
    total: 170000,
    paid: 50000,
  );
  final freon = job(
    'freon',
    title: 'شحن فريون',
    at: DateTime(2026, 7, 12, 12),
    total: 65000,
    paid: 65000,
  );
  final installation = job(
    'installation',
    title: 'تركيب كارير 2.25',
    at: DateTime(2023, 5, 3, 12),
    total: 110000,
    paid: 110000,
  );
  final karim = testCustomer(
    areaId: 'heliopolis',
    address: '7 شارع الحجاز',
    notes: 'بيحب المعاد بعد الضهر.',
  );
  final sharp = testUnit(nextServiceOn: DateTime(2027, 4));
  final carrier = testUnit(
    id: 'unit-2',
    brand: 'كارير',
    capacityHp: 2.25,
    room: 'أوضة النوم',
    installedYear: 2023,
  );

  CustomerState state({
    Customer? customer,
    List<CustomerUnit>? units,
    List<JobSummary>? jobs,
    Failure? failure,
    bool isGone = false,
  }) => CustomerState(
    today: today,
    record: CustomerRecord(
      customer: customer ?? karim,
      units: units ?? [sharp, carrier],
    ),
    jobs: jobs ?? [maintenance, freon, installation],
    failure: failure,
    isGone: isGone,
  );

  void show(CustomerState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const CustomerView(),
    repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
    blocs: [
      BlocProvider<CustomerCubit>.value(value: cubit),
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<AreasCubit>.value(value: areas),
    ],
    stubRoutes: [
      AppRoutes.editCustomer('customer-1'),
      AppRoutes.newJob,
      AppRoutes.job('freon'),
      AppRoutes.jobInvoice('older'),
      AppRoutes.jobInvoice('maintenance'),
      AppRoutes.technicianCustomers,
    ],
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

  testWidgets('shows only the header while loading', (tester) async {
    show(CustomerState(today: today));
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.customerEdit), findsNothing);
    expect(find.text(l10n.customerCall), findsNothing);
  });

  testWidgets('shows the customer the way the design does', (tester) async {
    show(state());
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('أ. كريم منصور'), findsOneWidget);
    expect(find.text(l10n.customerOwes('male')), findsOneWidget);
    expect(find.text('1,200 ج.م', findRichText: true), findsOneWidget);
    expect(find.text('دفع 500 من 1,700'), findsOneWidget);
    expect(find.text('0122 870 3314'), findsOneWidget);
    expect(find.text('7 شارع الحجاز، مصر الجديدة'), findsOneWidget);
    expect(find.text('شارب 1.5 حصان · الصالة'), findsOneWidget);
    expect(find.text('من 2021'), findsOneWidget);
    expect(find.text('كارير 2.25 حصان · أوضة النوم'), findsOneWidget);
    expect(find.text('التنظيف الجاي: أول أبريل'), findsOneWidget);
    expect(find.text('شغلانة جديدة لكريم'), findsOneWidget);

    await scrollTo(tester, find.text('تركيب كارير 2.25'));
    expect(tester.takeException(), isNull);
    expect(find.text('بيحب المعاد بعد الضهر.'), findsOneWidget);
    expect(find.text(l10n.customerJobs(3)), findsOneWidget);
    expect(find.text('باقي 1,200'), findsOneWidget);
    expect(find.text('26 سبتمبر'), findsOneWidget);
    expect(find.text('اتدفعت'), findsNWidgets(2));
    expect(find.text('3 مايو 2023'), findsOneWidget);
  });

  testWidgets('speaks to a woman as one', (tester) async {
    show(state(customer: testCustomer(name: 'مدام سهير عبد الله')));
    await pumpPage(tester);

    expect(find.text(l10n.customerOwes('female')), findsOneWidget);
    expect(find.text('دفعت 500 من 1,700'), findsOneWidget);
    expect(find.text(l10n.remindCustomerFeminine), findsOneWidget);
    expect(find.text(l10n.customerUnits('female')), findsOneWidget);
    expect(find.text('شغلانة جديدة لسهير'), findsOneWidget);
  });

  testWidgets('leaves out what the customer does not have', (tester) async {
    show(
      state(
        customer: testCustomer(phone: null),
        units: const [],
        jobs: const [],
      ),
    );
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.customerCall), findsNothing);
    expect(find.text(l10n.customerWhatsapp), findsNothing);
    expect(find.text(l10n.customerOwes('male')), findsNothing);
    expect(find.text(l10n.customerDetails), findsNothing);
    expect(find.text(l10n.customerNotes), findsNothing);
    expect(find.text(l10n.customerNoUnits), findsOneWidget);
    expect(find.text(l10n.unitAdd), findsOneWidget);
    expect(find.text(l10n.customerJobs(0)), findsNothing);
  });

  testWidgets('says when a cleaning is overdue', (tester) async {
    show(state(units: [testUnit(nextServiceOn: DateTime(2026, 9, 15))]));
    await pumpPage(tester);

    expect(find.text('معاد التنظيف عدّى: 15 سبتمبر'), findsOneWidget);
  });

  group('reaching the customer', () {
    testWidgets('calls', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerCall));
      await tester.pump();

      verify(() => apps.dial(phone)).called(1);
    });

    testWidgets('opens their WhatsApp chat', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerWhatsapp));
      await tester.pump();

      verify(() => apps.whatsApp(text: '', to: phone)).called(1);
    });

    testWidgets('calls from their number too', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text('0122 870 3314'));
      await tester.pump();

      verify(() => apps.dial(phone)).called(1);
    });

    testWidgets('opens their address on the map', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text('7 شارع الحجاز، مصر الجديدة'));
      await tester.pump();

      verify(() => apps.map('7 شارع الحجاز، مصر الجديدة')).called(1);
    });
  });

  group('money owed', () {
    testWidgets('reminds them of all of it on WhatsApp', (tester) async {
      final older = job(
        'older',
        title: 'شحن فريون',
        at: DateTime(2026, 7, 12),
        status: JobStatus.finished,
        total: 65000,
      );
      final owing = state(jobs: [maintenance, older]);
      show(owing);
      await pumpPage(tester);

      expect(find.text('1,850 ج.م', findRichText: true), findsOneWidget);
      await tester.tap(find.text(l10n.remindCustomer));
      await tester.pump();

      final text =
          verify(
                () => apps.whatsApp(
                  text: captureAny(named: 'text'),
                  to: phone,
                ),
              ).captured.single
              as String;
      expect(
        text,
        customerReminderMessage(
          l10n,
          customerName: 'أ. كريم منصور',
          owed: owing.owedJobs,
          technicianName: 'محمود عبد الله',
        ),
      );
      expect(text, contains('فاضل 1,850 ج.م من حساب شغلانتين'));
    });

    testWidgets('records a payment on the oldest unpaid job', (tester) async {
      show(
        state(
          jobs: [
            maintenance,
            job(
              'older',
              title: 'شحن فريون',
              at: DateTime(2026, 7, 12),
              status: JobStatus.finished,
              total: 65000,
            ),
          ],
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerRecordPayment));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobInvoice('older')), findsOneWidget);
    });

    testWidgets('without a phone, only records the payment', (tester) async {
      show(state(customer: testCustomer(phone: null)));
      await pumpPage(tester);

      expect(find.text(l10n.remindCustomer), findsNothing);
      await tester.tap(find.text(l10n.customerRecordPayment));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobInvoice('maintenance')), findsOneWidget);
    });
  });

  group('units', () {
    setUp(() {
      when(
        () => cubit.saveUnit(any(), unitId: any(named: 'unitId')),
      ).thenAnswer((_) async => true);
      when(() => cubit.deleteUnit(any())).thenAnswer((_) async => true);
      when(() => cubit.restoreUnit(any())).thenAnswer((_) async => true);
    });

    testWidgets('adds one', (tester) async {
      show(state());
      await pumpPage(tester);

      await scrollTo(tester, find.text(l10n.unitAdd));
      await tester.tap(find.text(l10n.unitAdd));
      await tester.pumpAndSettle();
      expect(find.text(l10n.unitAddTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'يونيون إير');
      await tester.tap(find.text('2.25 حصان'));
      await tester.ensureVisible(find.text(l10n.unitSave));
      await tester.tap(find.text(l10n.unitSave));
      await tester.pumpAndSettle();

      verify(
        () => cubit.saveUnit(
          const CustomerUnitDraft(brand: 'يونيون إير', capacityHp: 2.25),
        ),
      ).called(1);
    });

    testWidgets('changes one', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text('كارير 2.25 حصان · أوضة النوم'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.unitEditTitle), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(1), 'الصالة');
      await tester.ensureVisible(find.text(l10n.unitSave));
      await tester.tap(find.text(l10n.unitSave));
      await tester.pumpAndSettle();

      verify(
        () => cubit.saveUnit(
          const CustomerUnitDraft(
            brand: 'كارير',
            capacityHp: 2.25,
            room: 'الصالة',
            installedYear: 2023,
          ),
          unitId: 'unit-2',
        ),
      ).called(1);
    });

    testWidgets('deletes one, with undo', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text('كارير 2.25 حصان · أوضة النوم'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(l10n.unitDelete));
      await tester.tap(find.text(l10n.unitDelete));
      await tester.pumpAndSettle();

      verify(() => cubit.deleteUnit('unit-2')).called(1);
      expect(find.text(l10n.unitDeleted), findsOneWidget);

      await tester.tap(find.text(l10n.unitRestore));
      verify(() => cubit.restoreUnit(carrier)).called(1);
    });

    testWidgets('does nothing when the sheet is dismissed', (tester) async {
      show(state());
      await pumpPage(tester);

      await scrollTo(tester, find.text(l10n.unitAdd));
      await tester.tap(find.text(l10n.unitAdd));
      await tester.pumpAndSettle();
      expect(find.text(l10n.unitAddTitle), findsOneWidget);
      Navigator.of(tester.element(find.text(l10n.unitAddTitle))).pop();
      await tester.pumpAndSettle();

      expect(find.text(l10n.unitAddTitle), findsNothing);
      verifyNever(() => cubit.saveUnit(any(), unitId: any(named: 'unitId')));
    });

    testWidgets('says when a change failed', (tester) async {
      whenListen(
        cubit,
        Stream.value(state(failure: const UnexpectedFailure())),
        initialState: state(),
      );
      await pumpPage(tester);
      await tester.pump();

      expect(find.text(l10n.errorUnexpected), findsOneWidget);
    });
  });

  group('going elsewhere', () {
    testWidgets('edits the customer', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerEdit));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.editCustomer('customer-1')), findsOneWidget);
    });

    testWidgets('starts a job for them', (tester) async {
      show(state());
      await pumpPage(tester);

      await tester.tap(find.text('شغلانة جديدة لكريم'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newJob), findsOneWidget);
    });

    testWidgets('opens a job', (tester) async {
      show(state());
      await pumpPage(tester);

      await scrollTo(tester, find.text('شحن فريون'));
      await tester.tap(find.text('شحن فريون'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('freon')), findsOneWidget);
    });

    testWidgets('leaves once the customer is deleted', (tester) async {
      whenListen(
        cubit,
        Stream.value(CustomerState(today: today, isGone: true)),
        initialState: state(),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianCustomers), findsOneWidget);
    });
  });
}
