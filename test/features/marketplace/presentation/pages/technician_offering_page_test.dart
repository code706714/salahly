import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_offering_page.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  late MockAreasCubit areas;
  late MockCategoriesCubit categories;

  const offering = TechnicianOffering(
    services: [
      ServicePrice(serviceId: 'ac_inspection', startingPricePiastres: 12000),
    ],
    areaIds: {'nasr_city'},
    workDays: {6, 7},
    radiusKm: 15,
  );

  setUpAll(() async {
    await loadAppFonts();
    registerFallbackValue(offering);
  });

  setUp(() {
    requests = MockTechnicianRequestsRepository();
    areas = MockAreasCubit();
    categories = MockCategoriesCubit();
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => categories.state).thenReturn(
      const CategoriesState(
        categories: [TestCategories.airConditioning, TestCategories.plumbing],
      ),
    );
    when(categories.load).thenAnswer((_) async {});
    when(requests.fetchOffering).thenAnswer((_) async => const Ok(offering));
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const TechnicianOfferingPage(),
    repositories: [
      RepositoryProvider<TechnicianRequestsRepository>.value(value: requests),
    ],
    blocs: [
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
    ],
    surfaceSize: const Size(360, 1400),
  );

  testWidgets('waits for what the technician offers now', (tester) async {
    await pumpPage(tester);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.offeringSave), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('shows it, ready to change', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.offeringTitle), findsOneWidget);
    expect(find.text(TestCategories.airConditioning.name), findsOneWidget);
    expect(find.text(TestCategories.plumbing.name), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(TestAreas.nasrCity.name), findsOneWidget);
    expect(find.text(l10n.offeringSave), findsOneWidget);
  });

  testWidgets('says why it could not be fetched, and tries again', (
    tester,
  ) async {
    when(
      requests.fetchOffering,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text(l10n.retry), findsOneWidget);
    expect(find.text(l10n.offeringSave), findsNothing);

    when(requests.fetchOffering).thenAnswer((_) async => const Ok(offering));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.offeringSave), findsOneWidget);
  });

  testWidgets('asks for a price instead of saving without one', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '120'), '');
    await tester.tap(find.text(l10n.offeringSave));
    await tester.pumpAndSettle();

    expect(find.text(l10n.techPriceInvalid), findsOneWidget);
    verifyNever(() => requests.updateOffering(any()));
  });

  testWidgets('says why the server refused, and stays', (tester) async {
    when(
      () => requests.updateOffering(any()),
    ).thenAnswer((_) async => const Err(NotVerifiedFailure()));
    await pumpPage(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.offeringSave));
    await tester.pumpAndSettle();

    expect(
      find.text(
        technicianOfferFailureMessage(l10n, const NotVerifiedFailure()),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.offeringSave), findsOneWidget);
  });
}
