import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/offer_negotiation.dart';

import '../../../../../helpers/incoming_fixtures.dart';
import '../../../../../helpers/mocks.dart';
import '../../../../../pump_app.dart';

void main() {
  late MockOfferCubit cubit;
  late MockTechnicianRequestsRepository requests;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    cubit = MockOfferCubit();
    requests = MockTechnicianRequestsRepository();
    when(() => cubit.state).thenReturn(OfferState(now: DateTime(2026, 10, 2)));
    when(() => cubit.reviseOffer(any())).thenAnswer((_) async => true);
    when(cubit.acceptCounter).thenAnswer((_) async => true);
    when(cubit.withdrawOffer).thenAnswer((_) async => true);
  });

  Future<void> pumpOffer(WidgetTester tester, MyOffer offer) => tester.pumpApp(
    Scaffold(
      body: SingleChildScrollView(child: OfferNegotiation(offer: offer)),
    ),
    repositories: [
      RepositoryProvider<TechnicianRequestsRepository>.value(value: requests),
    ],
    blocs: [BlocProvider<OfferCubit>.value(value: cubit)],
  );

  final countered = testMyOffer(counterPricePiastres: 30000, revisionsLeft: 1);

  group('an offer nobody asked about', () {
    testWidgets('can be lowered or taken back, and says how often', (
      tester,
    ) async {
      await pumpOffer(tester, testMyOffer());

      expect(find.text(l10n.negRevise), findsOneWidget);
      expect(find.text(l10n.negRevisionsLeft(2)), findsOneWidget);
      expect(find.text(l10n.negWithdraw), findsOneWidget);
      expect(find.text(l10n.offersThread), findsNothing);
      expect(find.text(l10n.negCounterBody), findsNothing);
    });

    testWidgets('lowers the price to one inside the range', (tester) async {
      await pumpOffer(tester, testMyOffer());
      await tester.tap(find.text(l10n.negRevise));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '400');
      await tester.tap(find.text(l10n.negReviseConfirm));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      verifyNever(() => cubit.reviseOffer(any()));

      await tester.enterText(find.byType(TextField), '320');
      await tester.tap(find.text(l10n.negReviseConfirm));
      await tester.pumpAndSettle();

      verify(() => cubit.reviseOffer(32000)).called(1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('leaves the price alone when the dialog is dismissed', (
      tester,
    ) async {
      await pumpOffer(tester, testMyOffer());
      await tester.tap(find.text(l10n.negRevise));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.priceDialogCancel));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.reviseOffer(any()));
    });

    testWidgets('cannot be lowered once the revisions are used up', (
      tester,
    ) async {
      await pumpOffer(tester, testMyOffer(revisionsLeft: 0));

      expect(find.text(l10n.negRevise), findsNothing);
      expect(find.text(l10n.negWithdraw), findsOneWidget);
    });

    testWidgets('is taken back after asking twice', (tester) async {
      await pumpOffer(tester, testMyOffer());

      await tester.tap(find.text(l10n.negWithdraw));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.negKeep));
      await tester.pumpAndSettle();
      verifyNever(cubit.withdrawOffer);

      await tester.tap(find.text(l10n.negWithdraw));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.negWithdrawConfirm));
      await tester.pumpAndSettle();

      verify(cubit.withdrawOffer).called(1);
    });
  });

  group('an offer the consumer asked a price for', () {
    testWidgets('shows the price asked, and what can be done about it', (
      tester,
    ) async {
      await pumpOffer(tester, countered);

      expect(find.text(l10n.negCounterTitle('300 ج.م')), findsOneWidget);
      expect(find.text(l10n.negAccept('300 ج.م')), findsOneWidget);
      expect(find.text(l10n.negRevise), findsOneWidget);
      expect(find.text(l10n.offersThread), findsOneWidget);
    });

    testWidgets('takes that price after one confirmation', (tester) async {
      await pumpOffer(tester, countered);

      await tester.tap(find.text(l10n.negAccept('300 ج.م')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.negAcceptTitle('300 ج.م')), findsOneWidget);
      await tester.tap(find.text(l10n.negAcceptConfirm));
      await tester.pumpAndSettle();

      verify(cubit.acceptCounter).called(1);
    });

    testWidgets('asks for a price above the one asked', (tester) async {
      await pumpOffer(tester, countered);
      await tester.tap(find.text(l10n.negRevise));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '300');
      await tester.tap(find.text(l10n.negReviseConfirm));
      await tester.pump();
      verifyNever(() => cubit.reviseOffer(any()));

      await tester.enterText(find.byType(TextField), '310');
      await tester.tap(find.text(l10n.negReviseConfirm));
      await tester.pumpAndSettle();

      verify(() => cubit.reviseOffer(31000)).called(1);
    });

    testWidgets('does nothing while another action runs', (tester) async {
      when(() => cubit.state).thenReturn(
        OfferState(now: DateTime(2026, 10, 2), busy: OfferAction.revise),
      );
      await pumpOffer(tester, countered);

      await tester.tap(find.text(l10n.negRevise));
      await tester.tap(find.text(l10n.negWithdraw));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('shows the talk so far', (tester) async {
      when(() => requests.fetchOfferThread('offer-1')).thenAnswer(
        (_) async => Ok(
          OfferThread(
            state: const OfferTalk(
              offerId: 'offer-1',
              requestId: 'request-1',
              status: OfferStatus.sent,
              pricePiastres: 35000,
              counterPricePiastres: 30000,
              awaiting: OfferTurn.technician,
              countersLeft: 2,
              revisionsLeft: 1,
            ),
            events: [
              OfferEvent(
                kind: OfferEventKind.offer,
                actor: UserRole.technician,
                pricePiastres: 35000,
                createdAt: DateTime(2026, 10, 2, 20),
              ),
              OfferEvent(
                kind: OfferEventKind.counter,
                actor: UserRole.consumer,
                pricePiastres: 30000,
                createdAt: DateTime(2026, 10, 2, 21),
              ),
            ],
          ),
        ),
      );
      await pumpOffer(tester, countered);

      await tester.tap(find.text(l10n.offersThread));
      await tester.pumpAndSettle();

      expect(find.text(l10n.threadTechnicianOffer('350 ج.م')), findsOneWidget);
      expect(
        find.text(l10n.threadTechnicianCounter('300 ج.م')),
        findsNWidgets(2),
      );
    });
  });
}
