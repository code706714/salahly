import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_form_cubit.dart';
import 'package:salahly/features/customers/presentation/pages/customer_form_page.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockCustomerFormCubit extends MockCubit<CustomerFormState>
    implements CustomerFormCubit {}

void main() {
  late _MockCustomerFormCubit cubit;
  late MockAreasCubit areas;
  final karim = testCustomer();

  const adding = CustomerFormState(
    isEditing: false,
    status: CustomerFormStatus.editing,
  );
  const editing = CustomerFormState(
    isEditing: true,
    status: CustomerFormStatus.editing,
    name: 'أ. كريم منصور',
    phoneText: '01228703314',
    areaId: 'heliopolis',
    address: '7 شارع الحجاز',
    notes: 'بيحب المعاد بعد الضهر',
  );

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = _MockCustomerFormCubit();
    areas = MockAreasCubit();
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => cubit.save()).thenAnswer((_) async {});
    when(() => cubit.delete()).thenAnswer((_) async {});
  });

  void show(CustomerFormState state) =>
      when(() => cubit.state).thenReturn(state);

  List<BlocProvider<StateStreamableSource<Object?>>> blocs() => [
    BlocProvider<CustomerFormCubit>.value(value: cubit),
    BlocProvider<AreasCubit>.value(value: areas),
  ];

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const CustomerFormView(),
    blocs: blocs(),
    stubRoutes: [
      AppRoutes.technicianCustomers,
      AppRoutes.customer('customer-1'),
    ],
  );

  /// Scrolls the form down to its delete button.
  Future<void> scrollToDelete(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text(l10n.customerDelete),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  /// Opens the form from another screen, like the new job screen does,
  /// and returns what it closed with.
  Future<Completer<Customer?>> pumpOpened(WidgetTester tester) async {
    tester.view
      ..physicalSize = smallPhone * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final result = Completer<Customer?>();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result.complete(await context.push<Customer>('/form')),
              child: const Text('open'),
            ),
          ),
        ),
        GoRoute(
          path: '/form',
          builder: (context, state) => const CustomerFormView(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: blocs(),
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('waits for the customer or the contact', (tester) async {
    show(const CustomerFormState(isEditing: false));
    await pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });

  group('a new customer', () {
    testWidgets('asks for their details', (tester) async {
      show(adding);
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.customerNewTitle), findsOneWidget);
      expect(find.text(l10n.customerName), findsOneWidget);
      expect(find.text(l10n.customerPhone), findsOneWidget);
      expect(find.text(l10n.customerArea), findsOneWidget);
      expect(find.text(l10n.areaPickerTitle), findsOneWidget);
      expect(find.text(l10n.customerSavesOffline), findsOneWidget);
      expect(find.text(l10n.customerDelete), findsNothing);
    });

    testWidgets('passes on what is typed', (tester) async {
      when(() => cubit.nameChanged(any())).thenReturn(null);
      when(() => cubit.phoneChanged(any())).thenReturn(null);
      when(() => cubit.addressChanged(any())).thenReturn(null);
      when(() => cubit.notesChanged(any())).thenReturn(null);
      show(adding);
      await pumpPage(tester);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'أ. كريم');
      await tester.enterText(fields.at(1), '٠١٢٢abc٨');
      await tester.enterText(fields.at(2), '7 شارع الحجاز');
      await tester.enterText(fields.at(3), 'البواب عم رجب');

      verify(() => cubit.nameChanged('أ. كريم')).called(1);
      verify(() => cubit.phoneChanged('٠١٢٢٨')).called(1);
      verify(() => cubit.addressChanged('7 شارع الحجاز')).called(1);
      verify(() => cubit.notesChanged('البواب عم رجب')).called(1);
    });

    testWidgets('picks the area from the list', (tester) async {
      when(() => cubit.areaChanged(any())).thenReturn(null);
      show(adding);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.areaPickerTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المعادي'));
      await tester.pumpAndSettle();

      verify(() => cubit.areaChanged('maadi')).called(1);
    });

    testWidgets('saves', (tester) async {
      show(adding);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerSave));

      verify(() => cubit.save()).called(1);
    });

    testWidgets('points out what is missing', (tester) async {
      show(
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
          phoneText: '0122',
          showErrors: true,
        ),
      );
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.customerNameInvalid), findsOneWidget);
      expect(find.text(l10n.phoneInvalid), findsOneWidget);
    });

    testWidgets('is busy while saving', (tester) async {
      show(
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.saving,
        ),
      );
      await pumpPage(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.customerSave), findsNothing);
    });

    testWidgets('says why saving failed', (tester) async {
      show(
        const CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
          failure: UnexpectedFailure(),
        ),
      );
      await pumpPage(tester);

      expect(find.text(l10n.errorUnexpected), findsOneWidget);
    });

    testWidgets('hands back who already has the number', (tester) async {
      show(
        CustomerFormState(
          isEditing: false,
          status: CustomerFormStatus.editing,
          phoneText: '01228703314',
          duplicate: karim,
        ),
      );
      final result = await pumpOpened(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.customerExists('أ. كريم منصور')), findsOneWidget);
      await tester.tap(find.text(l10n.customerOpen));
      await tester.pumpAndSettle();

      expect(await result.future, karim);
    });

    testWidgets('closes with the customer once saved', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          CustomerFormState(
            isEditing: false,
            status: CustomerFormStatus.saved,
            saved: karim,
          ),
        ),
        initialState: const CustomerFormState(isEditing: false),
      );
      final result = await pumpOpened(tester);

      expect(await result.future, karim);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('closes with nothing when cancelled', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const CustomerFormState(
            isEditing: false,
            status: CustomerFormStatus.cancelled,
          ),
        ),
        initialState: const CustomerFormState(isEditing: false),
      );
      final result = await pumpOpened(tester);

      expect(await result.future, isNull);
    });

    testWidgets('closes with nothing when the technician backs out', (
      tester,
    ) async {
      show(adding);
      final result = await pumpOpened(tester);

      await tester.tap(find.byTooltip(l10n.back));
      await tester.pumpAndSettle();

      expect(await result.future, isNull);
    });

    testWidgets('shows the customers tab when nothing opened it', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(
          CustomerFormState(
            isEditing: false,
            status: CustomerFormStatus.saved,
            saved: karim,
          ),
        ),
        initialState: const CustomerFormState(isEditing: false),
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianCustomers), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('shows what is saved', (tester) async {
      show(editing);
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.customerEditTitle), findsOneWidget);
      expect(find.text('أ. كريم منصور'), findsOneWidget);
      expect(find.text('01228703314'), findsOneWidget);
      expect(find.text('مصر الجديدة'), findsOneWidget);
      expect(find.text('7 شارع الحجاز'), findsOneWidget);
      expect(find.text('بيحب المعاد بعد الضهر'), findsOneWidget);
    });

    testWidgets('clears the area', (tester) async {
      when(() => cubit.areaChanged(any())).thenReturn(null);
      show(editing);
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.customerAreaClear));

      verify(() => cubit.areaChanged(null)).called(1);
    });

    testWidgets('opens who already has the number', (tester) async {
      show(
        CustomerFormState(
          isEditing: true,
          status: CustomerFormStatus.editing,
          name: 'م. شريف عادل',
          phoneText: '01228703314',
          duplicate: karim,
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.customerOpen));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.customer('customer-1')), findsOneWidget);
    });

    testWidgets('deletes after explaining what goes with them', (
      tester,
    ) async {
      show(editing);
      await pumpPage(tester);

      await scrollToDelete(tester);
      await tester.tap(find.text(l10n.customerDelete));
      await tester.pumpAndSettle();
      expect(find.text('تمسح أ. كريم منصور؟'), findsOneWidget);
      expect(find.text(l10n.customerDeleteBody('male')), findsOneWidget);
      await tester.tap(find.text(l10n.customerDeleteConfirm));
      await tester.pumpAndSettle();

      verify(() => cubit.delete()).called(1);
    });

    testWidgets('keeps the customer when the technician changes their mind', (
      tester,
    ) async {
      show(editing);
      await pumpPage(tester);

      await scrollToDelete(tester);
      await tester.tap(find.text(l10n.customerDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.back));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.delete());
    });

    testWidgets('goes to the customers tab once deleted', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          const CustomerFormState(
            isEditing: true,
            status: CustomerFormStatus.deleted,
          ),
        ),
        initialState: editing,
      );
      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianCustomers), findsOneWidget);
    });
  });
}
