import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/onboarding/presentation/cubit/consumer_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/pages/consumer_onboarding_page.dart';

import '../../../../pump_app.dart';

class _MockConsumerOnboardingCubit extends MockCubit<ConsumerOnboardingState>
    implements ConsumerOnboardingCubit {}

class _MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

const nasrCity = ServiceArea(
  id: 'nasr-city',
  name: 'مدينة نصر',
  city: 'القاهرة',
  center: GeoPoint(lat: 30.0561, lng: 31.3301),
);
const maadi = ServiceArea(
  id: 'maadi',
  name: 'المعادي',
  city: 'القاهرة',
  center: GeoPoint(lat: 29.9602, lng: 31.2569),
);
const ready = ConsumerOnboardingState(
  loadStatus: LoadStatus.ready,
  areas: [nasrCity, maadi],
);

void main() {
  late ConsumerOnboardingCubit cubit;
  late SessionCubit session;

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = _MockConsumerOnboardingCubit();
    session = _MockSessionCubit();
    when(() => cubit.state).thenReturn(ready);
    when(() => cubit.load()).thenAnswer((_) async {});
    when(() => cubit.submit()).thenAnswer((_) async {});
    when(() => session.state).thenReturn(const SessionLoading());
    when(() => session.refreshProfile()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const ConsumerOnboardingPage(),
    blocs: [
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<ConsumerOnboardingCubit>.value(value: cubit),
    ],
  );

  group('ConsumerOnboardingPage', () {
    testWidgets('shows a spinner while loading', (tester) async {
      when(() => cubit.state).thenReturn(const ConsumerOnboardingState());

      await pumpPage(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.consumerOnboardingTitle), findsNothing);
    });

    testWidgets('explains a failed load and retries', (tester) async {
      when(() => cubit.state).thenReturn(
        const ConsumerOnboardingState(
          loadStatus: LoadStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpPage(tester);
      expect(find.text(l10n.errorNetwork), findsOneWidget);

      await tester.tap(find.text(l10n.retry));

      verify(() => cubit.load()).called(1);
    });

    testWidgets('fits the form on a small phone', (tester) async {
      when(() => cubit.state).thenReturn(ready.copyWith(freeRequests: 2));

      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.consumerOnboardingTitle), findsOneWidget);
      expect(find.text(l10n.honorificMr), findsOneWidget);
      expect(find.text(l10n.honorificMs), findsOneWidget);
      expect(find.text(l10n.areaPick), findsOneWidget);
      expect(find.text(l10n.consumerStart), findsOneWidget);
    });

    testWidgets('passes the name and honorific to the cubit', (tester) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextFormField), 'منى');
      await tester.tap(find.text(l10n.honorificMs));

      verify(() => cubit.nameChanged('منى')).called(1);
      verify(() => cubit.honorificChanged(Honorific.ms)).called(1);
    });

    testWidgets('keeps start enabled so a tap can reveal what is missing', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.consumerStart));

      verify(() => cubit.submit()).called(1);
    });

    testWidgets('flags the missing fields once the cubit shows errors', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(ready.copyWith(showErrors: true));

      await pumpPage(tester);

      expect(find.text(l10n.nameInvalid), findsOneWidget);
      expect(find.text(l10n.honorificRequired), findsOneWidget);
      expect(find.text(l10n.honorificHint), findsNothing);
    });

    testWidgets('picks the area from the area sheet', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.areaPick));
      await tester.pumpAndSettle();
      await tester.tap(find.text(maadi.name));
      await tester.pumpAndSettle();

      verify(() => cubit.areaPicked(maadi)).called(1);
    });

    testWidgets('says when the area came from the GPS', (tester) async {
      when(() => cubit.state).thenReturn(
        ready.copyWith(
          honorific: Honorific.ms,
          area: nasrCity,
          areaSource: AreaSource.location,
        ),
      );

      await pumpPage(tester);

      expect(find.text(nasrCity.name), findsOneWidget);
      expect(find.text(l10n.consumerAreaFromGps('ms')), findsOneWidget);
      expect(find.text(l10n.consumerAreaQuestion('ms')), findsOneWidget);
    });

    testWidgets('offers the free requests in the honorific chosen', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        ready.copyWith(freeRequests: 2, honorific: Honorific.ms),
      );

      await pumpPage(tester);

      expect(
        find.text(l10n.consumerFreeRequestsMs(l10n.freeRequestsCount(2))),
        findsOneWidget,
      );
    });

    testWidgets('shows a submit failure above the button', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(ready.copyWith(failure: () => const NetworkFailure()));

      await pumpPage(tester);

      expect(find.text(l10n.errorNetwork), findsOneWidget);
      expect(find.text(l10n.consumerStart), findsOneWidget);
    });

    testWidgets('refreshes the session once onboarding is done', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(ready.copyWith(isDone: true)),
        initialState: ready,
      );

      await pumpPage(tester);
      await tester.pump();

      verify(() => session.refreshProfile()).called(1);
    });
  });
}
