import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/presentation/cubit/customers_cubit.dart';
import 'package:salahly/features/customers/presentation/pages/customers_page.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockCustomersCubit extends MockCubit<CustomersState>
    implements CustomersCubit {}

void main() {
  late _MockCustomersCubit cubit;
  late MockSyncCubit sync;
  late MockAreasCubit areas;
  final today = DateTime(2026, 10, 2);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(CustomerFilter.all);
  });

  setUp(() {
    cubit = _MockCustomersCubit();
    sync = MockSyncCubit();
    areas = MockAreasCubit();
    when(() => sync.state).thenReturn(const SyncState());
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
  });

  void show(
    List<CustomerSummary>? customers, {
    String query = '',
    CustomerFilter filter = CustomerFilter.all,
  }) => when(() => cubit.state).thenReturn(
    CustomersState(
      today: today,
      customers: customers,
      query: query,
      filter: filter,
    ),
  );

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const CustomersView(),
    blocs: [
      BlocProvider<CustomersCubit>.value(value: cubit),
      BlocProvider<SyncCubit>.value(value: sync),
      BlocProvider<AreasCubit>.value(value: areas),
    ],
    stubRoutes: [AppRoutes.newCustomer, AppRoutes.customer('customer-1')],
  );

  // The customers of the design.
  final karim = testCustomerSummary(
    testCustomer(areaId: 'heliopolis'),
    jobCount: 3,
    owedPiastres: 120000,
    owedSince: DateTime(2026, 9, 26, 15),
    lastFinishedAt: DateTime(2026, 9, 26, 15),
  );
  final sohair = testCustomerSummary(
    testCustomer(
      id: 'customer-2',
      name: 'مدام سهير عبد الله',
      areaId: 'nasr_city',
    ),
    jobCount: 1,
    owedPiastres: 140000,
    owedSince: DateTime(2026, 9, 20, 12),
    lastFinishedAt: DateTime(2026, 9, 20, 12),
  );
  final nourhan = testCustomerSummary(
    testCustomer(
      id: 'customer-3',
      name: 'نورهان م.',
      areaId: 'nasr_city',
      source: CustomerSource.platform,
    ),
    jobCount: 1,
    nextScheduledAt: DateTime(2026, 10, 3, 11),
  );
  final essam = testCustomerSummary(
    testCustomer(id: 'customer-4', name: 'أ. عصام بدر', areaId: 'maadi'),
    unitCount: 3,
  );
  final hala = testCustomerSummary(
    testCustomer(id: 'customer-5', name: 'أ. هالة فتحي', areaId: 'nasr_city'),
    jobCount: 1,
    owedPiastres: 65000,
    owedSince: DateTime(2026, 10, 2, 9),
    lastFinishedAt: DateTime(2026, 10, 2, 9),
  );
  final everyone = [karim, sohair, nourhan, essam, hala];

  testWidgets('shows only the header while loading', (tester) async {
    show(null);
    await pumpPage(tester);

    expect(find.text(l10n.customersTitle, findRichText: true), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(l10n.customersEmptyTitle), findsNothing);
  });

  group('no customers yet', () {
    setUp(() => show(const []));

    testWidgets('says so calmly and offers the two ways to add', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.customersEmptyTitle), findsOneWidget);
      expect(find.text(l10n.customersEmptyContacts), findsOneWidget);
      expect(find.text(l10n.customersEmptyAdd), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('brings them in from the contacts', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customersEmptyContacts));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newCustomer), findsOneWidget);
    });

    testWidgets('adds one by hand', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customersEmptyAdd));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newCustomer), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('shows each customer the way the design does', (
      tester,
    ) async {
      show(everyone);
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('العملاء 5', findRichText: true), findsOneWidget);
      expect(
        find.text('مصر الجديدة · آخر شغلانة من 6 أيام'),
        findsOneWidget,
      );
      expect(find.text('مدينة نصر · آخر شغلانة من 12 يوم'), findsOneWidget);
      expect(
        find.text('مدينة نصر · من المنصة · عنده شغلانة بكره'),
        findsOneWidget,
      );
      expect(find.text('المعادي · 3 تكييفات'), findsOneWidget);
      expect(find.text('مدينة نصر · خلصت النهارده'), findsOneWidget);
    });

    testWidgets('shows who owes what, and what is only due today', (
      tester,
    ) async {
      show(everyone);
      await pumpPage(tester);

      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('عليه'), findsOneWidget);
      expect(find.text('1,400'), findsOneWidget);
      expect(find.text('عليها'), findsOneWidget);
      expect(find.text('650'), findsOneWidget);
      expect(find.text(l10n.customersDue), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(2));
    });

    testWidgets('opens a customer', (tester) async {
      show(everyone);
      await pumpPage(tester);

      await tester.tap(find.text('أ. كريم منصور'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.customer('customer-1')), findsOneWidget);
    });

    testWidgets('adds a customer', (tester) async {
      show(everyone);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customersAdd));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.newCustomer), findsOneWidget);
    });

    testWidgets('says when the search finds nobody', (tester) async {
      show(everyone, query: 'زياد');
      await pumpPage(tester);

      expect(find.text(l10n.customersNoResults), findsOneWidget);
      expect(find.text('أ. كريم منصور'), findsNothing);
    });

    testWidgets('tells the work is kept on the phone while offline', (
      tester,
    ) async {
      when(
        () => sync.state,
      ).thenReturn(const SyncState(hasNetwork: false, pendingChanges: 2));
      show(everyone);
      await pumpPage(tester);

      expect(
        find.textContaining(l10n.offlineTitle, findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('filters', () {
    testWidgets('show their counts and hide the empty ones', (tester) async {
      show(everyone);
      await pumpPage(tester);

      expect(find.text(l10n.customersFilterAll), findsOneWidget);
      expect(find.text(l10n.customersFilterOwing(3)), findsOneWidget);
      expect(find.text(l10n.customersFilterPlatform(1)), findsOneWidget);
      expect(find.text(l10n.customersFilterCleaning(0)), findsNothing);
    });

    testWidgets('keep all once no chip has anybody', (tester) async {
      show([essam]);
      await pumpPage(tester);

      expect(find.text(l10n.customersFilterAll), findsOneWidget);
      expect(find.text(l10n.customersFilterOwing(0)), findsNothing);
    });

    testWidgets('pick a chip', (tester) async {
      when(() => cubit.filterChanged(any())).thenReturn(null);
      show(everyone);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customersFilterOwing(3)));

      verify(() => cubit.filterChanged(CustomerFilter.owing)).called(1);
    });

    testWidgets('list only who the chip keeps', (tester) async {
      show(everyone, filter: CustomerFilter.platform);
      await pumpPage(tester);

      expect(find.text('نورهان م.'), findsOneWidget);
      expect(find.text('أ. كريم منصور'), findsNothing);
    });
  });

  testWidgets('searches as the technician types, and clears', (
    tester,
  ) async {
    when(() => cubit.queryChanged(any())).thenReturn(null);
    show(everyone);
    await pumpPage(tester);
    expect(find.byTooltip(l10n.customersSearchClear), findsNothing);

    await tester.enterText(find.byType(TextField), 'كريم');
    await tester.pump();
    verify(() => cubit.queryChanged('كريم')).called(1);

    await tester.tap(find.byTooltip(l10n.customersSearchClear));
    await tester.pump();
    verify(() => cubit.queryChanged('')).called(1);
    expect(find.text('كريم'), findsNothing);
  });
}
