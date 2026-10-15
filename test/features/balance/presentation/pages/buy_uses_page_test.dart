import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';
import 'package:salahly/features/balance/presentation/pages/buy_uses_page.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/balance_harness.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    BalanceHarness.registerFallbacks();
    registerFallbackValue(Uri());
  });

  const consumerState = BuyUsesState(
    status: BuyUsesStatus.editing,
    packs: consumerPacks,
    packId: 'pack-5',
  );
  final technicianState = consumerState.copyWith(
    packs: technicianPacks,
    packId: 'pack-t10',
  );
  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 8000,
  );

  BalanceHarness consumer({
    Honorific honorific = Honorific.ms,
    int credits = 0,
  }) => BalanceHarness(
    session: consumerWithCredits(honorific: honorific, credits: credits),
  );

  BalanceHarness technician({int credits = 0}) =>
      BalanceHarness(session: technicianSession(credits: credits));

  /// On a tall screen, so every step is on it; [smallPhone] tests scroll.
  Future<void> pump(
    WidgetTester tester,
    BalanceHarness harness,
    BuyUsesState state, {
    UserRole role = UserRole.consumer,
    Size surfaceSize = const Size(360, 1400),
  }) {
    when(() => harness.buyUses.state).thenReturn(state);
    return harness.pump(
      tester,
      BuyUsesView(role: role),
      surfaceSize: surfaceSize,
    );
  }

  Finder payButton(String label) => find.widgetWithText(FilledButton, label);

  group('for a consumer', () {
    testWidgets('shows the packs and how the payment goes', (tester) async {
      await pump(tester, consumer(), consumerState);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('ms')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(l10n.buyUsesPackConsumer(1)), findsOneWidget);
      expect(find.text(l10n.buyUsesPackConsumer(5)), findsOneWidget);
      expect(find.text(l10n.pounds('20')), findsOneWidget);
      expect(find.text(l10n.pounds('80')), findsOneWidget);
      expect(find.text(l10n.buyUsesNoteSingleConsumer), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingConsumer('ms', '16', '20')),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesPayHint('ms')), findsOneWidget);
    });

    testWidgets('says all the free requests are used when none are left', (
      tester,
    ) async {
      await pump(tester, consumer(), consumerState);

      expect(find.text(l10n.buyUsesConsumerIntroNone('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesConsumerIntroBody('ms')), findsOneWidget);
    });

    testWidgets('says how many are left when there are some', (tester) async {
      await pump(tester, consumer(credits: 1), consumerState);

      expect(
        find.text(
          '${l10n.consumerHomeCreditsLead('ms')} '
          '${l10n.consumerHomeCreditsCount(1)}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesConsumerIntroNone('ms')), findsNothing);
    });

    testWidgets('speaks to a man as a man', (tester) async {
      await pump(tester, consumer(honorific: Honorific.mr), consumerState);

      expect(find.text(l10n.buyUsesTitleConsumer('mr')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('mr')), findsOneWidget);
      expect(find.text(l10n.buyUsesConsumerIntroNone('mr')), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingConsumer('mr', '16', '20')),
        findsOneWidget,
      );
      expect(payButton(l10n.buyUsesPay('mr', '80')), findsOneWidget);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsNothing);
    });

    testWidgets('shows no savings for a pack that saves nothing', (
      tester,
    ) async {
      await pump(
        tester,
        consumer(),
        consumerState.copyWith(
          packs: const [
            CreditPack(id: 'pack-1', uses: 1, pricePiastres: 2000),
            CreditPack(id: 'pack-5', uses: 5, pricePiastres: 10000),
          ],
        ),
      );

      expect(find.text(l10n.buyUsesNotePerUseConsumer('20')), findsOneWidget);
    });
  });

  group('on the smallest phone', () {
    for (final (name, role) in [
      ('consumer', UserRole.consumer),
      ('technician', UserRole.technician),
    ]) {
      testWidgets('fits for a $name, down to the pay button', (tester) async {
        final harness = role == UserRole.consumer ? consumer() : technician();
        await pump(
          tester,
          harness,
          role == UserRole.consumer ? consumerState : technicianState,
          role: role,
          surfaceSize: smallPhone,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(FilledButton), findsOneWidget);
      });
    }
  });

  group('for a technician', () {
    testWidgets('shows the packs in the technician words', (
      tester,
    ) async {
      await pump(
        tester,
        technician(),
        technicianState,
        role: UserRole.technician,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesTitleTechnician), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('other')), findsOneWidget);
      expect(find.text(l10n.buyUsesPackTechnician(1)), findsOneWidget);
      expect(find.text(l10n.buyUsesPackTechnician(10)), findsOneWidget);
      expect(find.text(l10n.buyUsesNoteSingleTechnician), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingTechnician('25', '50')),
        findsOneWidget,
      );
      expect(payButton(l10n.buyUsesPay('other', '250')), findsOneWidget);
    });

    testWidgets('says the free jobs are gone and the balance is zero', (
      tester,
    ) async {
      await pump(
        tester,
        technician(),
        technicianState,
        role: UserRole.technician,
      );

      expect(find.text(l10n.buyUsesTechnicianIntroNone), findsOneWidget);
      expect(
        find.text(l10n.buyUsesTechnicianIntroBody(0)),
        findsOneWidget,
      );
      expect(find.textContaining('1,000'), findsOneWidget);
    });

    testWidgets('says how many jobs are left when there are some', (
      tester,
    ) async {
      await pump(
        tester,
        technician(credits: 1),
        technicianState,
        role: UserRole.technician,
      );

      expect(find.text(l10n.todayRequestsCreditsLeft(1)), findsOneWidget);
      expect(
        find.text(l10n.buyUsesTechnicianIntroBody(1)),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesTechnicianIntroNone), findsNothing);
    });
  });

  group('paying', () {
    testWidgets('picks a pack', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesPackConsumer(1)));

      verify(() => harness.buyUses.pickPack('pack-1')).called(1);
    });

    testWidgets('shows the price of the picked pack on the button', (
      tester,
    ) async {
      await pump(tester, consumer(), consumerState);

      expect(payButton(l10n.buyUsesPay('ms', '80')), findsOneWidget);
    });

    testWidgets('starts the payment from the button', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(payButton(l10n.buyUsesPay('ms', '80')));

      verify(harness.buyUses.pay).called(1);
    });

    testWidgets('shows the payment being started and cannot pay twice', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        consumerState.copyWith(status: BuyUsesStatus.starting),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      verifyNever(harness.buyUses.pay);
    });

    testWidgets('cannot be left while the payment is being started', (
      tester,
    ) async {
      final harness = consumer();
      final starting = consumerState.copyWith(status: BuyUsesStatus.starting);
      when(() => harness.buyUses.state).thenReturn(starting);
      whenListen(
        harness.buyUses,
        const Stream<BuyUsesState>.empty(),
        initialState: starting,
      );
      await harness.pump(tester, _openingView());
      await tester.tap(find.text('open'));
      await tester.pump(const Duration(seconds: 1));

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(BuyUsesView), findsOneWidget);
    });

    testWidgets('can be left while choosing', (tester) async {
      final harness = consumer();
      when(() => harness.buyUses.state).thenReturn(consumerState);
      whenListen(
        harness.buyUses,
        const Stream<BuyUsesState>.empty(),
        initialState: consumerState,
      );
      await harness.pump(tester, _openingView());
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(BuyUsesView), findsNothing);
    });

    testWidgets('thanks and closes once the server confirmed the payment', (
      tester,
    ) async {
      final harness = consumer();
      when(() => harness.buyUses.state).thenReturn(consumerState);
      when(harness.buyUses.paymentClosed).thenReturn(null);
      when(() => harness.apps.openLink(any())).thenAnswer((_) async => true);
      when(() => harness.payments.fetchOrder('order-1')).thenAnswer(
        (_) async => const Ok(
          PaymentOrder(id: 'order-1', status: PaymentStatus.succeeded),
        ),
      );
      whenListen(
        harness.buyUses,
        Stream.value(
          consumerState.copyWith(
            status: BuyUsesStatus.paying,
            checkout: () => checkout,
          ),
        ),
        initialState: consumerState,
      );
      final result = ValueNotifier<bool?>(null);
      await harness.pump(
        tester,
        _openingView(result: result),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(l10n.paymentDone));
      await tester.pumpAndSettle();

      expect(result.value, isTrue);
      expect(find.text(l10n.buyUsesPaid), findsOneWidget);
      verify(harness.buyUses.paymentClosed).called(1);
      verify(() => harness.apps.openLink(checkout.url)).called(1);
    });

    testWidgets('stays when the payment screen is left unpaid', (
      tester,
    ) async {
      final harness = consumer();
      when(() => harness.buyUses.state).thenReturn(consumerState);
      when(harness.buyUses.paymentClosed).thenReturn(null);
      when(() => harness.apps.openLink(any())).thenAnswer((_) async => true);
      when(() => harness.payments.fetchOrder('order-1')).thenAnswer(
        (_) async => const Ok(
          PaymentOrder(id: 'order-1', status: PaymentStatus.pending),
        ),
      );
      whenListen(
        harness.buyUses,
        Stream.value(
          consumerState.copyWith(
            status: BuyUsesStatus.paying,
            checkout: () => checkout,
          ),
        ),
        initialState: consumerState,
      );
      final result = ValueNotifier<bool?>(null);
      await harness.pump(
        tester,
        _openingView(result: result),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text(l10n.paymentLater));
      await tester.pumpAndSettle();

      expect(result.value, isNull);
      expect(find.text(l10n.buyUsesPaid), findsNothing);
      verify(harness.buyUses.paymentClosed).called(1);
    });

    for (final (name, failure, message) in <(String, Failure, String)>[
      (
        'a pack that is gone',
        const PackNotFoundFailure(),
        l10n.buyUsesPackGone('ms'),
      ),
      (
        'a changed price',
        const PriceChangedFailure(),
        l10n.buyUsesPriceChanged('ms'),
      ),
      (
        'payment that is not available',
        const PaymentsUnavailableFailure(),
        l10n.paymentsUnavailable('ms'),
      ),
      ('no network', const NetworkFailure(), l10n.consumerErrorNetwork('ms')),
      (
        'anything else',
        const UnexpectedFailure(),
        l10n.consumerErrorUnexpected('ms'),
      ),
    ]) {
      testWidgets('tells a consumer about $name', (tester) async {
        final harness = consumer();
        when(() => harness.buyUses.state).thenReturn(consumerState);
        whenListen(
          harness.buyUses,
          Stream.value(consumerState.copyWith(failure: () => failure)),
          initialState: consumerState,
        );
        await harness.pump(tester, const BuyUsesView(role: UserRole.consumer));
        await tester.pump();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('tells a technician in the technician words', (tester) async {
      final harness = technician();
      when(() => harness.buyUses.state).thenReturn(technicianState);
      whenListen(
        harness.buyUses,
        Stream.value(
          technicianState.copyWith(failure: () => const NetworkFailure()),
        ),
        initialState: technicianState,
      );
      await harness.pump(
        tester,
        const BuyUsesView(role: UserRole.technician),
      );
      await tester.pump();

      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });
  });

  group('before the packs are there', () {
    testWidgets('waits for them', (tester) async {
      await pump(tester, consumer(), const BuyUsesState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsOneWidget);
    });

    testWidgets('says when they could not be fetched, and retries', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        const BuyUsesState(status: BuyUsesStatus.failed),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesUnavailable('ms')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(find.text(l10n.retry));

      verify(harness.buyUses.load).called(1);
    });
  });
}

/// A button that opens the buy screen, reporting what it popped with.
Widget _openingView({ValueNotifier<bool?>? result}) => Scaffold(
  body: Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        final popped = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder: (_) => const BuyUsesView(role: UserRole.consumer),
          ),
        );
        result?.value = popped;
      },
      child: const Text('open'),
    ),
  ),
);
