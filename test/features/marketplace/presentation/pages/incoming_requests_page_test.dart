import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_requests_page.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockIncomingRequestsCubit cubit;
  late MockAreasCubit areas;
  late MockCategoriesCubit categories;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    cubit = MockIncomingRequestsCubit();
    areas = MockAreasCubit();
    categories = MockCategoriesCubit();
    when(() => cubit.fetchNewRequests()).thenAnswer((_) async {});
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(
      () => categories.state,
    ).thenReturn(const CategoriesState(categories: TestCategories.all));
  });

  /// A request sent 20 minutes ago for tomorrow noon.
  IncomingRequest recent({
    String id = 'request-1',
    MyOffer? myOffer,
    RequestStatus status = RequestStatus.open,
    int offerCount = 2,
    Honorific honorific = Honorific.ms,
    String areaId = 'nasr_city',
  }) {
    final now = DateTime.now();
    return testIncoming(
      id: id,
      createdAt: now.subtract(const Duration(minutes: 20)),
      day: DateTime(now.year, now.month, now.day + 1),
      expiresAt: now.add(const Duration(days: 1)),
      myOffer: myOffer,
      status: status,
      offerCount: offerCount,
      honorific: honorific,
      areaId: areaId,
    );
  }

  void show(IncomingRequestsState state) =>
      when(() => cubit.state).thenReturn(state);

  IncomingRequestsState ready(
    List<IncomingRequest> requests, {
    Set<String> closedIds = const {},
  }) => IncomingRequestsState(
    status: IncomingRequestsStatus.ready,
    requests: requests,
    closedIds: closedIds,
  );

  Future<void> pumpView(
    WidgetTester tester, {
    Widget view = const IncomingRequestsView(),
  }) => tester.pumpApp(
    view,
    blocs: [
      BlocProvider<IncomingRequestsCubit>.value(value: cubit),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
    ],
    stubRoutes: [AppRoutes.incomingRequest('request-1')],
  );

  Finder dimmed(String text) => find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate(
      (widget) => widget is Opacity && widget.opacity < 1,
    ),
  );

  group('states', () {
    testWidgets('waits for the first list', (tester) async {
      show(const IncomingRequestsState());
      await pumpView(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.incomingTitle), findsOneWidget);
    });

    testWidgets('says when the list could not be fetched', (tester) async {
      show(
        const IncomingRequestsState(
          status: IncomingRequestsStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.incomingLoadFailed), findsOneWidget);
      await tester.tap(find.text(l10n.retry));
      verify(() => cubit.fetchNewRequests()).called(1);
    });

    testWidgets('says when there are no requests', (tester) async {
      show(ready(const []));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.incomingEmpty), findsOneWidget);
      expect(find.text(l10n.incomingEmptyHint), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('shows what, who, where and when, and the offers so far', (
      tester,
    ) async {
      show(ready([recent()]));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('تكييف مش بيبرّد'), findsOneWidget);
      expect(find.text('من 20 دقيقة'), findsOneWidget);
      expect(find.text('نورهان م. · مدينة نصر · 2.4 كم منك'), findsOneWidget);
      expect(find.textContaining('من 12 لـ 3 الضهر'), findsOneWidget);
      expect(find.text(l10n.incomingOfferCount(2, 3)), findsOneWidget);
    });

    testWidgets('marks the offer sent, and the closed requests dimmed', (
      tester,
    ) async {
      show(
        ready(
          [
            recent(myOffer: testMyOffer()),
            recent(
              id: 'chosen',
              status: RequestStatus.assigned,
              myOffer: testMyOffer(status: OfferStatus.accepted),
            ),
            recent(id: 'other', status: RequestStatus.assigned),
            recent(id: 'gone', honorific: Honorific.mr),
          ],
          closedIds: {'gone'},
        ),
      );
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('بعتّ عرضك · 350 ج.م'), findsOneWidget);
      expect(find.text('اختارت عرضك'), findsOneWidget);
      expect(dimmed('اختارت عرضك'), findsNothing);
      expect(find.text('اختارت فني تاني'), findsOneWidget);
      expect(dimmed('اختارت فني تاني'), findsOneWidget);
      expect(find.text(l10n.incomingClosed), findsOneWidget);
      expect(dimmed(l10n.incomingClosed), findsOneWidget);
      // Offers so far only on requests still in play.
      expect(find.text(l10n.incomingOfferCount(2, 3)), findsOneWidget);
    });

    testWidgets('opens a request', (tester) async {
      show(ready([recent()]));
      await pumpView(tester);

      await tester.tap(find.text('تكييف مش بيبرّد'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.incomingRequest('request-1')), findsOne);
    });

    testWidgets('fetches the list again when pulled', (tester) async {
      show(ready([recent()]));
      await pumpView(tester);

      await tester.fling(
        find.text('تكييف مش بيبرّد'),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      verify(() => cubit.fetchNewRequests()).called(1);
    });

    testWidgets('pulls an empty list too', (tester) async {
      show(ready(const []));
      await pumpView(tester);

      await tester.fling(
        find.text(l10n.incomingEmpty),
        const Offset(0, 400),
        1000,
      );
      await tester.pumpAndSettle();

      verify(() => cubit.fetchNewRequests()).called(1);
    });
  });

  testWidgets('fetches the list on opening', (tester) async {
    show(ready(const []));
    await pumpView(tester, view: const IncomingRequestsPage());
    verify(() => cubit.fetchNewRequests()).called(1);
  });
}
