import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/offers_view.dart';

import '../../../../../helpers/marketplace_fixtures.dart';
import '../../../../../helpers/request_views_fixtures.dart';
import '../../../../../helpers/request_views_harness.dart';
import '../../../../../pump_app.dart';

void main() {
  late ConsumerViewHarness harness;

  /// Tall enough to show every offer at once.
  const tall = Size(360, 1600);

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() => harness = ConsumerViewHarness());

  Future<void> pumpView(WidgetTester tester, {Size surfaceSize = smallPhone}) =>
      harness.pump(
        tester,
        OffersView(details: harness.request.state.details!),
        surfaceSize: surfaceSize,
        stubRoutes: [
          for (final id in ['tech-1', 'tech-2', 'tech-3'])
            AppRoutes.technicianProfile(id),
        ],
      );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// The technicians' names from the top of the screen down.
  List<String> namesInOrder(WidgetTester tester) {
    final names = {
      for (final name in ['ياسر عبد الحميد', 'محمود السيد', 'أحمد رمضان'])
        name: tester.getTopLeft(find.text(name)).dy,
    };
    return names.keys.toList()..sort((a, b) => names[a]!.compareTo(names[b]!));
  }

  final verifiedShield = find.byWidgetPredicate(
    (widget) => widget is Icon && widget.semanticLabel == l10n.offersVerified,
  );

  Finder cardOf(String name) =>
      find.ancestor(of: find.text(name), matching: find.byType(AppCard));

  group('shows', () {
    testWidgets('the offers, nearest first', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      await pumpView(tester, surfaceSize: tall);
      expect(find.text(l10n.offersTitle), findsOneWidget);
      expect(
        find.text('تكييف مش بيبرّد · بكره الضهر 12 لـ 3'),
        findsOneWidget,
      );
      expect(
        find.text('وصلك 3 عروض من 5 فنيين اتبعتلهم الطلب'),
        findsOneWidget,
      );
      expect(namesInOrder(tester), [
        'ياسر عبد الحميد',
        'محمود السيد',
        'أحمد رمضان',
      ]);
      expect(find.textContaining('4.9 (31 تقييم) · 40 شغلانة'), findsOneWidget);
      expect(find.text('1.2 كم منك'), findsOneWidget);
      expect(find.text('بكره 12:30'), findsOneWidget);
      expect(find.text(l10n.offersStartingPrice), findsNWidgets(3));
      expect(
        find.text('"غالباً محتاج تنظيف وشحن بسيط، هكشف وأقولك."'),
        findsOneWidget,
      );
      expect(find.text('اختاري ياسر'), findsOneWidget);
      expect(find.text(l10n.offersProfile), findsNWidgets(3));
      expect(verifiedShield, findsNWidgets(3));

      expect(find.text(l10n.offersPricesNote('ms')), findsOneWidget);
    });

    testWidgets('a technician with no ratings yet, and no distance', (
      tester,
    ) async {
      harness.show(
        liveRequest(
          offers: [
            RequestOffer(
              id: 'offer-1',
              pricePiastres: 35000,
              arriveAt: tomorrowAt(13),
              status: OfferStatus.sent,
              createdAt: DateTime.now(),
              technician: testTechnicianCard(
                rating: null,
                reviewCount: 0,
                jobsDone: 0,
                verified: false,
              ),
            ),
          ],
          sentTo: 1,
        ),
      );

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('وصلك عرض واحد من فني واحد اتبعتله الطلب'),
        findsOneWidget,
      );
      expect(
        find.text('${l10n.offersNoReviews} · ${l10n.offersJobsDone(0)}'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(verifiedShield, findsNothing);
      expect(find.textContaining('كم منك'), findsNothing);
      expect(find.textContaining('"'), findsNothing);
    });

    testWidgets('his words to a man', (tester) async {
      harness = ConsumerViewHarness(honorific: Honorific.mr)
        ..show(liveRequest(offers: liveOffers()));

      await pumpView(tester, surfaceSize: tall);

      expect(find.text('اختار ياسر'), findsOneWidget);
      expect(find.text(l10n.offersPricesNote('other')), findsOneWidget);
    });
  });

  group('sorts', () {
    testWidgets('by price', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester, surfaceSize: tall);

      await tester.tap(find.text(l10n.offersSortCheapest));
      await tester.pumpAndSettle();

      expect(namesInOrder(tester), [
        'أحمد رمضان',
        'محمود السيد',
        'ياسر عبد الحميد',
      ]);
    });

    testWidgets('by rating', (tester) async {
      harness.show(
        liveRequest(
          offers: [
            ...liveOffers().take(2),
            testOffer(
              id: 'offer-3',
              technician: testTechnicianCard(
                id: 'tech-3',
                name: 'أحمد رمضان',
                rating: null,
              ),
            ),
          ],
        ),
      );
      await pumpView(tester, surfaceSize: tall);

      await tester.tap(find.text(l10n.offersSortTopRated));
      await tester.pumpAndSettle();
      expect(namesInOrder(tester), [
        'ياسر عبد الحميد',
        'محمود السيد',
        'أحمد رمضان',
      ]);

      await tester.tap(find.text(l10n.offersSortNearest));
      await tester.pumpAndSettle();
      expect(namesInOrder(tester).first, 'ياسر عبد الحميد');
    });
  });

  group('picking', () {
    testWidgets('asks first, naming the price and time, then picks', (
      tester,
    ) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester);

      await tapAndSettle(tester, find.text('اختاري ياسر'));
      expect(find.text('تختاري ياسر؟'), findsOneWidget);
      expect(
        find.text(
          'هييجي بكره 12:30 الضهر، والسعر المبدئي 400 ج.م. '
          'العروض التانية هتتقفل.',
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text('اختاري ياسر').last);

      verify(() => harness.request.acceptOffer('offer-1')).called(1);
    });

    testWidgets('waits when she changes her mind', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester);

      await tapAndSettle(tester, find.text('اختاري محمود'));
      await tapAndSettle(tester, find.text('لأ، استني'));

      expect(find.text('تختاري محمود؟'), findsNothing);
      verifyNever(() => harness.request.acceptOffer(any()));
    });

    testWidgets('shows the progress on the picked offer only', (tester) async {
      final details = liveRequest(offers: liveOffers());
      final states = StreamController<RequestState>();
      addTearDown(states.close);
      final picking = Completer<bool>();
      when(
        () => harness.request.acceptOffer(any()),
      ).thenAnswer((_) => picking.future);
      harness.show(details);
      whenListen(
        harness.request,
        states.stream,
        initialState: harness.request.state,
      );
      await pumpView(tester, surfaceSize: tall);

      await tapAndSettle(tester, find.text('اختاري محمود'));
      await tapAndSettle(tester, find.text('اختاري محمود').last);
      states.add(
        RequestState(
          status: RequestLoadStatus.ready,
          details: details,
          busy: RequestAction.acceptOffer,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('اختاري محمود'), findsNothing);
      expect(
        find.descendant(
          of: cardOf('محمود السيد'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      final other = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('اختاري ياسر'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(other.onPressed, isNull);
      final profile = tester.widget<OutlinedButton>(
        find
            .ancestor(
              of: find.text(l10n.offersProfile),
              matching: find.byType(OutlinedButton),
            )
            .first,
      );
      expect(profile.onPressed, isNull);

      picking.complete(false);
      states.add(
        RequestState(status: RequestLoadStatus.ready, details: details),
      );
      await tester.pumpAndSettle();
      expect(find.text('اختاري محمود'), findsOneWidget);
    });
  });

  group("the technician's page", () {
    testWidgets('opens for the offer', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.offersProfile).first);

      expect(find.text(AppRoutes.technicianProfile('tech-2')), findsOneWidget);
      verifyNever(() => harness.request.acceptOffer(any()));
    });

    testWidgets('picks the offer when she picks it there', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester);
      await tapAndSettle(tester, find.text(l10n.offersProfile).first);

      final page = tester.element(
        find.text(AppRoutes.technicianProfile('tech-2')),
      );
      GoRouter.of(page).pop(true);
      await tester.pumpAndSettle();

      verify(() => harness.request.acceptOffer('offer-1')).called(1);
    });

    testWidgets('picks nothing when she comes back', (tester) async {
      harness.show(liveRequest(offers: liveOffers()));
      await pumpView(tester);
      await tapAndSettle(tester, find.text(l10n.offersProfile).last);

      final page = tester.element(
        find.text(AppRoutes.technicianProfile('tech-3')),
      );
      GoRouter.of(page).pop();
      await tester.pumpAndSettle();

      expect(find.text(l10n.offersTitle), findsOneWidget);
      verifyNever(() => harness.request.acceptOffer(any()));
    });
  });
}
