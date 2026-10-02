import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/pages/technician_onboarding_page.dart';

import '../../../../pump_app.dart';

class _MockTechnicianOnboardingCubit
    extends MockCubit<TechnicianOnboardingState>
    implements TechnicianOnboardingCubit {}

class _MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

const cleaning = CatalogService(
  id: 'ac-cleaning',
  name: 'تنظيف تكييف',
  suggestedPricePiastres: 35000,
);
const installation = CatalogService(
  id: 'ac-installation',
  name: 'تركيب تكييف',
  suggestedPricePiastres: 80000,
);
const categories = [
  ServiceCategory(
    id: 'ac',
    name: 'تكييف',
    isActive: true,
    services: [cleaning, installation],
  ),
  ServiceCategory(id: 'plumbing', name: 'سباكة', isActive: false, services: []),
];
const areas = [
  ServiceArea(
    id: 'nasr-city',
    name: 'مدينة نصر',
    city: 'القاهرة',
    center: GeoPoint(lat: 30.0561, lng: 31.3301),
  ),
  ServiceArea(
    id: 'heliopolis',
    name: 'مصر الجديدة',
    city: 'القاهرة',
    center: GeoPoint(lat: 30.0911, lng: 31.3225),
  ),
  ServiceArea(
    id: 'new-cairo',
    name: 'التجمع الخامس',
    city: 'القاهرة الجديدة',
    center: GeoPoint(lat: 30.0074, lng: 31.4913),
  ),
  ServiceArea(
    id: 'maadi',
    name: 'المعادي',
    city: 'القاهرة',
    center: GeoPoint(lat: 29.9602, lng: 31.2569),
  ),
];

/// A form filled in up to the documents, shown on the profile step.
final filledIn = TechnicianOnboardingState(
  loadStatus: LoadStatus.ready,
  categories: categories,
  areas: areas,
  freeJobs: 3,
  fullName: 'محمد السيد',
  shopName: 'تكييفات السيد',
  yearsText: '12',
  selectedServiceIds: {cleaning.id},
  priceTexts: {cleaning.id: '350'},
  baseArea: areas.first,
  baseLocation: areas.first.center,
  baseSource: AreaSource.location,
  areaIds: {areas.first.id, areas.last.id},
);

void main() {
  late TechnicianOnboardingCubit cubit;
  late SessionCubit session;

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = _MockTechnicianOnboardingCubit();
    session = _MockSessionCubit();
    when(() => cubit.state).thenReturn(filledIn);
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.next()).thenAnswer((_) async {});
    when(() => cubit.back()).thenReturn(true);
    when(() => session.state).thenReturn(const SessionLoading());
    when(() => session.refreshProfile()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const TechnicianOnboardingPage(),
    blocs: [
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<TechnicianOnboardingCubit>.value(value: cubit),
    ],
  );

  group('TechnicianOnboardingPage', () {
    testWidgets('shows a spinner while the catalog loads', (tester) async {
      when(() => cubit.state).thenReturn(const TechnicianOnboardingState());

      await pumpPage(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.next), findsNothing);
    });

    testWidgets('explains a failed load and retries', (tester) async {
      when(() => cubit.state).thenReturn(
        const TechnicianOnboardingState(
          loadStatus: LoadStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpPage(tester);
      expect(find.text(l10n.errorNetwork), findsOneWidget);

      await tester.tap(find.text(l10n.retry));

      verify(() => cubit.load()).called(1);
    });

    testWidgets('starts on the profile step, shown as step 1 of 4', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text(l10n.techOnboardingTitle), findsOneWidget);
      expect(find.text(l10n.techStepOf(1, 4)), findsOneWidget);
      expect(find.text(l10n.techProfileTitle), findsOneWidget);
      expect(find.text(l10n.next), findsOneWidget);
    });

    testWidgets('asks the cubit to move on when next is tapped', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.next));

      verify(() => cubit.next()).called(1);
    });

    testWidgets('goes back a step with the back button', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(filledIn.copyWith(step: TechnicianStep.services));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.back));

      verify(() => cubit.back()).called(1);
    });

    testWidgets('goes back a step with the system back gesture', (
      tester,
    ) async {
      when(
        () => cubit.state,
      ).thenReturn(filledIn.copyWith(step: TechnicianStep.location));
      await pumpPage(tester);

      await tester.binding.handlePopRoute();

      verify(() => cubit.back()).called(1);
    });

    for (final step in TechnicianStep.values) {
      testWidgets('fits the ${step.name} step on a small phone', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(filledIn.copyWith(step: step));

        await pumpPage(tester);

        expect(tester.takeException(), isNull);
        expect(
          find.text(
            step == TechnicianStep.done
                ? l10n.techStepsDone
                : l10n.techStepOf(step.index + 1, 4),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('asks to retake the photos when they were rejected', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        filledIn.copyWith(
          step: TechnicianStep.documents,
          failure: () => const InvalidPhotosFailure(),
        ),
      );

      await pumpPage(tester);

      expect(find.text(l10n.techDocsRejected), findsOneWidget);
      expect(find.text(l10n.techSubmit), findsOneWidget);
    });

    testWidgets('refreshes the session from the done step', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(filledIn.copyWith(step: TechnicianStep.done));
      await pumpPage(tester);
      expect(find.byTooltip(l10n.back), findsNothing);

      await tester.tap(find.text(l10n.techStart));

      verify(() => session.refreshProfile()).called(1);
    });
  });
}
