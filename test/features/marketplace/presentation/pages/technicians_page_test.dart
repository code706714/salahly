import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_directory_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/technicians_page.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockDirectoryCubit extends MockCubit<TechnicianDirectoryState>
    implements TechnicianDirectoryCubit {}

void main() {
  late _MockDirectoryCubit cubit;
  late MockAreasCubit areas;
  late MockCategoriesCubit categories;
  late MockSessionCubit session;

  setUpAll(() async {
    await loadAppFonts();
    registerFallbackValue(TechnicianSort.rating);
  });

  setUp(() {
    cubit = _MockDirectoryCubit();
    areas = MockAreasCubit();
    categories = MockCategoriesCubit();
    session = MockSessionCubit();
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.loadMore).thenAnswer((_) async {});
    when(() => cubit.selectCategory(any())).thenAnswer((_) async {});
    when(() => cubit.selectArea(any())).thenAnswer((_) async {});
    when(() => cubit.selectSort(any())).thenAnswer((_) async {});
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => categories.state).thenReturn(
      const CategoriesState(
        categories: [TestCategories.airConditioning, TestCategories.plumbing],
      ),
    );
    when(() => session.state).thenReturn(const SessionLoading());
  });

  void show(TechnicianDirectoryState state) =>
      when(() => cubit.state).thenReturn(state);

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    const TechniciansView(),
    blocs: [
      BlocProvider<TechnicianDirectoryCubit>.value(value: cubit),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
      BlocProvider<SessionCubit>.value(value: session),
    ],
    stubRoutes: [AppRoutes.technicianProfile('tech-1')],
  );

  TechnicianDirectoryState ready(
    List<TechnicianListing> technicians, {
    String? categoryId,
    String? areaId,
    TechnicianSort sort = TechnicianSort.rating,
  }) => TechnicianDirectoryState(
    status: TechnicianDirectoryStatus.ready,
    technicians: technicians,
    categoryId: categoryId,
    areaId: areaId,
    sort: sort,
  );

  group('states', () {
    testWidgets('waits for the first page', (tester) async {
      show(const TechnicianDirectoryState());
      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.directoryTitle), findsOneWidget);
    });

    testWidgets('says when nobody fits, with the filters still there', (
      tester,
    ) async {
      show(ready(const []));
      await pumpView(tester);

      expect(find.text(l10n.directoryEmpty), findsOneWidget);
      expect(find.text(l10n.directoryEmptyHint), findsOneWidget);
      expect(find.text(l10n.directorySortPrice), findsOneWidget);
    });

    testWidgets('says why the list could not be fetched, and tries again', (
      tester,
    ) async {
      show(
        const TechnicianDirectoryState(
          status: TechnicianDirectoryStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpView(tester);

      expect(find.text(l10n.consumerRetry('other')), findsOneWidget);
      await tester.tap(find.text(l10n.consumerRetry('other')));

      verify(cubit.load).called(1);
    });

    testWidgets('lists each technician with his price, and opens his page', (
      tester,
    ) async {
      show(ready([testListing(), testListing(id: 'tech-2', name: 'سامي علي')]));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('محمود السيد'), findsOneWidget);
      expect(find.text('سامي علي'), findsOneWidget);
      expect(find.text(l10n.priceFrom), findsNWidgets(2));

      await tester.tap(find.text('محمود السيد'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianProfile('tech-1')), findsOneWidget);
    });

    testWidgets('leaves out the price of a technician who has none', (
      tester,
    ) async {
      show(ready([testListing(minPricePiastres: null)]));
      await pumpView(tester);

      expect(find.text(l10n.priceFrom), findsNothing);
    });
  });

  group('filters', () {
    testWidgets('picks a trade, or all of them', (tester) async {
      show(ready([testListing()], categoryId: 'plumbing'));
      await pumpView(tester);

      await tester.tap(find.text(TestCategories.airConditioning.name));
      verify(() => cubit.selectCategory('ac')).called(1);

      await tester.tap(find.text(l10n.directoryAll));
      verify(() => cubit.selectCategory(null)).called(1);
    });

    testWidgets('picks the order', (tester) async {
      show(ready([testListing()]));
      await pumpView(tester);

      await tester.ensureVisible(find.text(l10n.directorySortPrice));
      await tester.tap(find.text(l10n.directorySortPrice));

      verify(() => cubit.selectSort(TechnicianSort.price)).called(1);
    });

    testWidgets('picks an area, and lets it go', (tester) async {
      show(ready([testListing()]));
      await pumpView(tester);

      await tester.tap(find.text(l10n.directoryAllAreas));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TestAreas.heliopolis.name));
      await tester.pumpAndSettle();

      verify(() => cubit.selectArea('heliopolis')).called(1);

      show(ready([testListing()], areaId: 'heliopolis'));
      await pumpView(tester);
      expect(find.text(TestAreas.heliopolis.name), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.directoryAllAreas));

      verify(() => cubit.selectArea(null)).called(1);
    });
  });
}
