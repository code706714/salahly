import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/incoming_request_page.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

void main() {
  late MockOfferCubit cubit;
  late MockIncomingRequestsCubit incoming;
  late MockSessionCubit session;
  late MockAreasCubit areas;
  late MockCategoriesCubit categories;
  final friday = DateTime(2026, 10, 2, 20);
  const services = [
    ServicePrice(
      serviceId: 'ac_inspection_cleaning',
      startingPricePiastres: 35000,
    ),
    ServicePrice(serviceId: 'ac_freon_recharge', startingPricePiastres: 65000),
    // Another category's service never goes with this request.
    ServicePrice(serviceId: 'plumbing_leak', startingPricePiastres: 20000),
  ];

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(
      OfferDraft(pricePiastres: 100, arriveAt: DateTime(2026)),
    );
  });

  SessionReady signedIn({int credits = 2}) => SessionReady(
    user: TechnicianApp.user,
    profile: UserProfile(
      id: 'user-1',
      phone: '+201002345678',
      fullName: 'محمود عبد الله',
      activeRole: UserRole.technician,
      technician: TechnicianProfile(
        verificationStatus: VerificationStatus.approved,
        jobCredits: credits,
      ),
    ),
  );

  setUp(() {
    cubit = MockOfferCubit();
    incoming = MockIncomingRequestsCubit();
    when(() => incoming.state).thenReturn(const IncomingRequestsState());
    session = MockSessionCubit();
    areas = MockAreasCubit();
    categories = MockCategoriesCubit();
    when(() => session.state).thenReturn(signedIn());
    when(() => session.refreshProfile()).thenAnswer((_) async {});
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(
      () => categories.state,
    ).thenReturn(const CategoriesState(categories: TestCategories.all));
    when(() => cubit.fetchRequest()).thenAnswer((_) async {});
    when(() => cubit.sendOffer(any())).thenAnswer((_) async => true);
    when(() => cubit.dismissRequest()).thenAnswer((_) async => true);
  });

  OfferState ready(
    IncomingRequest request, {
    Map<String, String> photoUrls = const {},
    OfferAction? busy,
    DateTime? now,
  }) => OfferState(
    now: now ?? friday,
    status: OfferLoadStatus.ready,
    request: request,
    services: services,
    photoUrls: photoUrls,
    busy: busy,
  );

  void show(OfferState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpView(
    WidgetTester tester, {
    Widget view = const IncomingRequestView(),
    List<String> stubRoutes = const [],
  }) => tester.pumpApp(
    view,
    stubRoutes: stubRoutes,
    blocs: [
      BlocProvider<OfferCubit>.value(value: cubit),
      BlocProvider<IncomingRequestsCubit>.value(value: incoming),
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
    ],
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Finder sendButton() => find.byWidgetPredicate(
    (widget) => widget is FilledButton,
  );

  group('states', () {
    testWidgets('waits for the request', (tester) async {
      show(OfferState(now: friday));
      await pumpView(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.incomingRequestTitle), findsOneWidget);
    });

    testWidgets('says when the request is not there', (tester) async {
      show(OfferState(now: friday, status: OfferLoadStatus.missing));
      await pumpView(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.marketplaceNotFound), findsOneWidget);
      expect(find.text(l10n.retry), findsNothing);
    });

    testWidgets('says when the request could not be fetched', (tester) async {
      show(OfferState(now: friday, status: OfferLoadStatus.failed));
      await pumpView(tester);

      expect(find.text(l10n.requestLoadFailed), findsOneWidget);
      await tester.tap(find.text(l10n.retry));
      verify(() => cubit.fetchRequest()).called(1);
    });
  });

  group('the request', () {
    testWidgets('shows what the consumer asked for, never where exactly', (
      tester,
    ) async {
      show(ready(testIncoming()));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('تكييف مش بيبرّد'), findsOneWidget);
      expect(find.text('من 20 دقيقة · العميلة: نورهان م.'), findsOneWidget);
      expect(find.textContaining('الهوا اللي طالع مش ساقع'), findsOneWidget);
      expect(find.text('مدينة نصر · 2.4 كم منك'), findsOneWidget);
      expect(find.text('بكره السبت، من 12 لـ 3 الضهر'), findsOneWidget);
      expect(find.text(l10n.incomingPrivacy('ms')), findsOneWidget);
      expect(
        find.text('الطلب راح لـ 5 فنيين، ووصل عرضين لحد دلوقتي'),
        findsOneWidget,
      );
    });

    testWidgets('speaks of a man as one', (tester) async {
      show(ready(testIncoming(honorific: Honorific.mr)));
      await pumpView(tester);

      expect(find.text('من 20 دقيقة · العميل: نورهان م.'), findsOneWidget);
      expect(find.text(l10n.incomingPrivacy('other')), findsOneWidget);
      await scrollTo(tester, find.text(l10n.offerFormNote('other')));
    });

    testWidgets('shows the photos and opens one full screen', (tester) async {
      show(
        ready(
          testIncoming(photoPaths: ['a.jpg', 'b.jpg']),
          photoUrls: {'a.jpg': 'https://photos/a.jpg'},
        ),
      );
      await pumpView(tester);

      expect(find.bySemanticsLabel(l10n.incomingPhoto), findsNWidgets(2));
      await tester.tap(find.bySemanticsLabel(l10n.incomingPhoto).first);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.jobPagePhotoClose));
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);

      // A photo without a link yet opens nothing.
      await tester.tap(find.bySemanticsLabel(l10n.incomingPhoto).last);
      await tester.pumpAndSettle();
      expect(find.byType(InteractiveViewer), findsNothing);
    });

    testWidgets('leaves out a missing description', (tester) async {
      show(ready(testIncoming(description: null)));
      await pumpView(tester);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('الهوا اللي طالع'), findsNothing);
    });
  });

  group('the offer form', () {
    testWidgets('sends the price, time and note picked', (tester) async {
      show(ready(testIncoming()));
      await pumpView(tester);

      expect(find.text(l10n.offerFormSendEmpty), findsOneWidget);
      expect(tester.widget<FilledButton>(sendButton()).onPressed, isNull);

      await scrollTo(tester, find.text('كشف وتنظيف 350'));
      expect(find.text('شحن فريون 650'), findsOneWidget);
      await tester.tap(find.text('كشف وتنظيف 350'));
      await tester.pump();
      expect(find.text(l10n.offerFormSend('350')), findsOneWidget);

      await scrollTo(tester, find.text('بكره 1:30'));
      // Every half hour of the window, from noon.
      expect(find.text('بكره 12:00'), findsOneWidget);
      expect(find.text('بكره 2:30'), findsOneWidget);
      expect(find.text('بكره 3:00'), findsNothing);
      await tester.tap(find.text('بكره 1:30'));
      await tester.pump();

      await scrollTo(tester, find.byType(TextField).last);
      expect(find.text(l10n.offerFormNote('ms')), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '  هجيب الفريون  ');
      await tester.tap(find.text(l10n.offerFormSend('350')));
      await tester.pump();

      verify(
        () => cubit.sendOffer(
          OfferDraft(
            serviceId: 'ac_inspection_cleaning',
            pricePiastres: 35000,
            arriveAt: DateTime(2026, 10, 3, 13, 30),
            note: 'هجيب الفريون',
          ),
        ),
      ).called(1);
    });

    testWidgets('takes a typed price, first time and no note', (tester) async {
      show(ready(testIncoming()));
      await pumpView(tester);

      await tester.enterText(find.byType(TextField).first, '400');
      await tester.pump();
      await tester.tap(find.text(l10n.offerFormSend('400')));
      await tester.pump();

      verify(
        () => cubit.sendOffer(
          OfferDraft(
            pricePiastres: 40000,
            arriveAt: DateTime(2026, 10, 3, 12),
          ),
        ),
      ).called(1);
    });

    testWidgets('offers only the times still to come', (tester) async {
      show(ready(testIncoming(), now: DateTime(2026, 10, 3, 13, 10)));
      await pumpView(tester);

      await scrollTo(tester, find.text('النهارده 1:30'));
      expect(find.text('النهارده 1:00'), findsNothing);
      expect(find.text('النهارده 2:30'), findsOneWidget);
    });

    testWidgets('waits while the offer is on its way', (tester) async {
      show(ready(testIncoming(), busy: OfferAction.send));
      await pumpView(tester);

      expect(
        find.descendant(
          of: sendButton(),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<TextButton>(find.byType(TextButton).last).onPressed,
        isNull,
      );
    });

    testWidgets('says why the offer was refused', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          ready(testIncoming()).copyWith(
            failure: () => const RequestClosedFailure(),
          ),
        ),
        initialState: ready(testIncoming()),
      );
      await pumpView(tester);
      await tester.pump();

      expect(find.text(l10n.technicianRequestClosed), findsOneWidget);
      verifyNever(() => session.refreshProfile());
    });

    testWidgets('reads the free jobs again when they ran out', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(
          ready(testIncoming()).copyWith(
            failure: () => const NoCreditsFailure(),
          ),
        ),
        initialState: ready(testIncoming()),
      );
      await pumpView(tester);
      await tester.pump();

      expect(find.text(l10n.technicianNoCredits), findsWidgets);
      verify(() => session.refreshProfile()).called(1);
    });
  });

  group('no offer possible', () {
    testWidgets('explains when no free jobs are left', (tester) async {
      when(() => session.state).thenReturn(signedIn(credits: 0));
      show(ready(testIncoming()));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.technicianNoCredits), findsOneWidget);
      expect(find.text(l10n.offerFormTitle), findsNothing);
      expect(sendButton(), findsOneWidget);
      expect(find.text(l10n.offerFormDismiss), findsOneWidget);
    });

    testWidgets('offers buying more when no free jobs are left', (
      tester,
    ) async {
      when(() => session.state).thenReturn(signedIn(credits: 0));
      show(ready(testIncoming()));
      await pumpView(tester, stubRoutes: [AppRoutes.technicianBuyUses]);

      await tester.tap(
        find.descendant(
          of: sendButton(),
          matching: find.text(l10n.buyUsesTitleTechnician),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianBuyUses), findsOneWidget);
    });

    testWidgets('explains when the credits are all held by waiting offers', (
      tester,
    ) async {
      when(() => session.state).thenReturn(signedIn(credits: 1));
      when(() => incoming.state).thenReturn(
        IncomingRequestsState(
          requests: [
            testIncoming(
              id: 'request-2',
              myOffer: MyOffer(
                id: 'offer-2',
                pricePiastres: 35000,
                arriveAt: DateTime(2026, 10, 4, 12),
                status: OfferStatus.sent,
              ),
            ),
          ],
        ),
      );
      show(ready(testIncoming()));
      await pumpView(tester);

      expect(find.text(l10n.technicianOffersWaiting), findsOneWidget);
      expect(sendButton(), findsNothing);
    });

    testWidgets("says when the request's time is over", (tester) async {
      show(ready(testIncoming(), now: DateTime(2026, 10, 3, 14, 45)));
      await pumpView(tester);

      expect(find.text(l10n.offerFormNoTimes), findsOneWidget);
      expect(sendButton(), findsNothing);
    });

    testWidgets('says why a closed request takes no offer', (tester) async {
      for (final (request, reason) in [
        (testIncoming(offerCount: 3), l10n.incomingClosedFull),
        (
          testIncoming(status: RequestStatus.cancelled),
          l10n.incomingClosedCancelled('ms'),
        ),
        (
          testIncoming(status: RequestStatus.assigned),
          l10n.incomingOfferNotChosen('ms'),
        ),
        (
          testIncoming(status: RequestStatus.expired),
          l10n.incomingClosedExpired,
        ),
      ]) {
        show(ready(request));
        await pumpView(tester);

        expect(tester.takeException(), isNull);
        expect(find.text(reason), findsOneWidget);
        expect(find.text(l10n.offerFormTitle), findsNothing);
        expect(find.text(l10n.offerFormDismiss), findsNothing);
      }
    });
  });

  group('the offer sent', () {
    testWidgets('shows it read-only, waiting for the consumer', (
      tester,
    ) async {
      show(ready(testIncoming(offerCount: 3, myOffer: testMyOffer())));
      await pumpView(tester);
      await scrollTo(tester, find.text('هجيب معايا الفريون'));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.offerFormTitle), findsOneWidget);
      expect(find.text(l10n.offerFormWaiting('ms')), findsOneWidget);
      expect(find.text('كشف وتنظيف'), findsOneWidget);
      expect(find.text('هتوصل بكره 12:30 الضهر'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text(l10n.offerFormDismiss), findsNothing);
      // A full request with this technician's offer isn't "closed" for them.
      expect(find.text(l10n.incomingClosedFull), findsNothing);
    });

    testWidgets('says when the consumer picked it', (tester) async {
      show(
        ready(
          testIncoming(
            status: RequestStatus.assigned,
            myOffer: testMyOffer(status: OfferStatus.accepted),
          ),
        ),
      );
      await pumpView(tester);
      await scrollTo(tester, find.text(l10n.offerFormChosenHint));

      expect(find.text('اختارت عرضك'), findsOneWidget);
    });

    testWidgets('says when the consumer picked someone else', (tester) async {
      show(
        ready(
          testIncoming(
            status: RequestStatus.assigned,
            myOffer: testMyOffer(status: OfferStatus.notChosen, note: null),
          ),
        ),
      );
      await pumpView(tester);
      await scrollTo(tester, find.text('اختارت فني تاني'));

      expect(find.text(l10n.offerFormChosenHint), findsNothing);
    });
  });

  group('not for me', () {
    testWidgets('dismisses the request once confirmed and leaves', (
      tester,
    ) async {
      show(ready(testIncoming()));
      await pumpView(tester, view: const PushedView(IncomingRequestView()));
      await tester.openPushedView();

      await tester.tap(find.text(l10n.offerFormDismiss));
      await tester.pumpAndSettle();
      expect(find.text(l10n.offerFormDismissTitle), findsOneWidget);
      await tester.tap(find.text(l10n.offerFormDismissKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.dismissRequest());

      await tester.tap(find.text(l10n.offerFormDismiss));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.offerFormDismissConfirm));
      await tester.pumpAndSettle();

      verify(() => cubit.dismissRequest()).called(1);
      expect(find.text(PushedView.launcher), findsOneWidget);
    });

    testWidgets('stays when it could not be dismissed', (tester) async {
      when(() => cubit.dismissRequest()).thenAnswer((_) async => false);
      show(ready(testIncoming()));
      await pumpView(tester, view: const PushedView(IncomingRequestView()));
      await tester.openPushedView();

      await tester.tap(find.text(l10n.offerFormDismiss));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.offerFormDismissConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.offerFormDismiss), findsOneWidget);
    });
  });

  testWidgets('any time of the day offers its every half hour', (
    tester,
  ) async {
    show(ready(testIncoming(window: RequestWindow.anyTime)));
    await pumpView(tester);
    await scrollTo(tester, find.text('بكره 8:30'));
    expect(tester.takeException(), isNull);
    expect(find.text('بكره 9:00'), findsOneWidget);
  });
}
