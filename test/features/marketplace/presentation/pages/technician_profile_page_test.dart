import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_profile_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/technician_profile_page.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/request_views_harness.dart';
import '../../../../pump_app.dart';

class MockTechnicianProfileCubit extends MockCubit<TechnicianProfileState>
    implements TechnicianProfileCubit {}

void main() {
  late ConsumerViewHarness harness;
  late MockTechnicianProfileCubit cubit;
  final today = DateTime(2026, 10, 6, 9);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    harness = ConsumerViewHarness();
    cubit = MockTechnicianProfileCubit();
    when(cubit.load).thenAnswer((_) async {});
  });

  void show(
    TechnicianProfileStatus status, {
    TechnicianPublicProfile? profile,
    Failure? failure,
  }) => when(() => cubit.state).thenReturn(
    TechnicianProfileState(
      today: today,
      status: status,
      profile: profile,
      failure: failure,
    ),
  );

  void showProfile([TechnicianPublicProfile? profile]) => show(
    TechnicianProfileStatus.ready,
    profile: profile ?? testTechnicianProfile(),
  );

  Future<void> pumpView(
    WidgetTester tester, {
    RequestOffer? offer,
    Size surfaceSize = smallPhone,
  }) => harness.pump(
    tester,
    TechnicianProfileView(offer: offer),
    blocs: [BlocProvider<TechnicianProfileCubit>.value(value: cubit)],
    stubRoutes: [AppRoutes.newRequest],
    surfaceSize: surfaceSize,
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  PublicReview review(int day) => PublicReview(
    author: 'عميل $day',
    stars: 5,
    comment: 'تعليق $day',
    issue: RequestIssue.needsCleaning,
    createdAt: DateTime(2026, 9, day),
  );

  testWidgets('shows who the technician is and what customers said', (
    tester,
  ) async {
    showProfile();

    await pumpView(tester, surfaceSize: const Size(360, 1400));

    expect(tester.takeException(), isNull);
    expect(find.text('محمود السيد'), findsOneWidget);
    expect(find.text('فني تكييف · 12 سنة خبرة'), findsOneWidget);
    expect(find.text('موثّق بالبطاقة'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
    expect(find.text('126 تقييم'), findsOneWidget);
    expect(find.text('214'), findsOneWidget);
    expect(find.text('شغلانة خلصت'), findsOneWidget);
    expect(find.text('98%'), findsOneWidget);
    expect(find.text('جه في معاده'), findsOneWidget);
    expect(find.text('مدينة نصر، مصر الجديدة'), findsOneWidget);
    expect(find.text('كشف وتنظيف'), findsOneWidget);
    expect(find.text('من 350 ج.م'), findsOneWidget);
    expect(find.text('شحن فريون'), findsOneWidget);
    expect(find.text('من 650 ج.م'), findsOneWidget);
    expect(find.text('دعاء م.'), findsOneWidget);
    expect(find.text('تنظيف تكييف · من أسبوعين'), findsOneWidget);
    expect(find.text('حسام ع.'), findsOneWidget);
    expect(find.text('تكييف مش بيبرّد · من شهر'), findsOneWidget);
    expect(find.text(l10n.techProfileAllReviews), findsNothing);
  });

  testWidgets('fits a small phone', (tester) async {
    showProfile();

    await pumpView(tester, offer: testOffer());
    await tester.scrollUntilVisible(find.text('حسام ع.'), 200);

    expect(tester.takeException(), isNull);
  });

  testWidgets('leaves out what a new technician has nothing to show for', (
    tester,
  ) async {
    showProfile(
      TechnicianPublicProfile(
        card: testTechnicianCard(rating: null, reviewCount: 0, jobsDone: 0),
        areaIds: const [],
        services: const [],
        reviews: const [],
      ),
    );

    await pumpView(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('0'), findsOneWidget);
    expect(find.text(l10n.techProfileOnTime), findsNothing);
    expect(find.text(l10n.techProfileAreas), findsNothing);
    expect(find.text(l10n.techProfilePrices), findsNothing);
    expect(find.text(l10n.techProfileNoReviews), findsOneWidget);
  });

  testWidgets('shows no badge for an unverified technician', (tester) async {
    showProfile(
      testTechnicianProfile(card: testTechnicianCard(verified: false)),
    );

    await pumpView(tester);

    expect(find.text(l10n.techProfileVerified), findsNothing);
  });

  testWidgets('shows the newest two reviews, and the rest on demand', (
    tester,
  ) async {
    final profile = testTechnicianProfile();
    showProfile(
      TechnicianPublicProfile(
        card: profile.card,
        areaIds: profile.areaIds,
        services: profile.services,
        reviews: [review(20), review(15), review(10), review(5)],
      ),
    );
    await pumpView(tester, surfaceSize: const Size(360, 1600));

    expect(find.text('عميل 20'), findsOneWidget);
    expect(find.text('عميل 15'), findsOneWidget);
    expect(find.text('عميل 10'), findsNothing);

    await tapAndSettle(tester, find.text(l10n.techProfileAllReviews));

    expect(tester.takeException(), isNull);
    for (final day in [20, 15, 10, 5]) {
      expect(find.text('عميل $day'), findsOneWidget);
    }
    expect(find.text(l10n.techProfileAllReviews), findsNothing);
  });

  group('while it is not ready', () {
    testWidgets('loads', (tester) async {
      show(TechnicianProfileStatus.loading);

      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.techProfilePageTitle), findsOneWidget);
    });

    testWidgets('says the technician is gone', (tester) async {
      show(TechnicianProfileStatus.notFound);

      await pumpView(tester);

      expect(find.text(l10n.techProfileNotFound), findsOneWidget);
    });

    testWidgets('fails and tries again', (tester) async {
      show(TechnicianProfileStatus.failed, failure: const NetworkFailure());
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.consumerErrorNetwork('ms')), findsOneWidget);

      await tester.tap(find.text(l10n.consumerRetry('ms')));

      verify(cubit.load).called(1);
    });
  });

  group('opened from an offer', () {
    testWidgets('picks it, naming the price', (tester) async {
      showProfile();
      bool? picked;
      await harness.pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider<TechnicianProfileCubit>.value(
                      value: cubit,
                      child: TechnicianProfileView(offer: testOffer()),
                    ),
                  ),
                ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('اختاري محمود · 350 ج.م'));
      await tester.pumpAndSettle();

      expect(picked, isTrue);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('speaks to a man in his words', (tester) async {
      harness = ConsumerViewHarness(honorific: Honorific.mr);
      showProfile();

      await pumpView(tester, offer: testOffer());

      expect(find.text('اختار محمود · 350 ج.م'), findsOneWidget);
    });
  });

  group('opened on its own', () {
    testWidgets('asks this technician in his trade', (tester) async {
      showProfile();
      await pumpView(tester);

      await tester.tap(find.text('اطلبي محمود'));
      await tester.pumpAndSettle();

      final page = tester.element(find.text(AppRoutes.newRequest));
      expect(
        GoRouterState.of(page).uri.toString(),
        AppRoutes.newRequestFor(categoryId: 'ac', technicianId: 'tech-1'),
      );
    });

    testWidgets('asks in the open trade when his prices say nothing', (
      tester,
    ) async {
      showProfile(
        TechnicianPublicProfile(
          card: testTechnicianCard(),
          areaIds: const [],
          services: const [],
          reviews: const [],
        ),
      );
      await pumpView(tester);

      expect(find.text('12 سنة خبرة'), findsNothing);
      expect(find.text('فني تكييف · 12 سنة خبرة'), findsOneWidget);

      await tester.tap(find.text('اطلبي محمود'));
      await tester.pumpAndSettle();

      final page = tester.element(find.text(AppRoutes.newRequest));
      expect(
        GoRouterState.of(page).uri.toString(),
        AppRoutes.newRequestFor(categoryId: 'ac', technicianId: 'tech-1'),
      );
    });

    testWidgets('speaks to a man in his words', (tester) async {
      harness = ConsumerViewHarness(honorific: Honorific.mr);
      showProfile();

      await pumpView(tester);

      expect(find.text('اطلب محمود'), findsOneWidget);
    });
  });
}
