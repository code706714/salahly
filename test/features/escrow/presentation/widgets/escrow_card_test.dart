import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:salahly/features/escrow/presentation/widgets/escrow_card.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  late FakeLiveUpdates live;
  late MockSessionCubit session;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    escrow = MockEscrowRepository();
    live = FakeLiveUpdates();
    session = MockSessionCubit();
    when(() => session.state).thenReturn(consumerSession());
  });

  void shows(EscrowInfo? info) => when(
    () => escrow.fetchInfo('request-1'),
  ).thenAnswer((_) async => Ok(info));

  Future<void> pump(
    WidgetTester tester, {
    List<String> stubRoutes = const [],
  }) async {
    await tester.pumpApp(
      const Scaffold(body: EscrowCard(requestId: 'request-1')),
      repositories: [
        RepositoryProvider<EscrowRepository>.value(value: escrow),
        RepositoryProvider<LiveUpdates>.value(value: live),
      ],
      blocs: [BlocProvider<SessionCubit>.value(value: session)],
      stubRoutes: stubRoutes,
    );
    await tester.pump();
  }

  group('what it says', () {
    testWidgets('offers to secure the money before the work', (tester) async {
      shows(testEscrowInfo(canSecure: true));

      await pump(tester);

      expect(find.text(l10n.escrowTitle), findsOneWidget);
      expect(find.text(l10n.escrowOfferBody('ms', '350')), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, l10n.escrowSecureAction('ms')),
        findsOneWidget,
      );
    });

    testWidgets('speaks to a man as a man', (tester) async {
      when(
        () => session.state,
      ).thenReturn(consumerSession(honorific: Honorific.mr));
      shows(testEscrowInfo(canSecure: true));

      await pump(tester);

      expect(find.text(l10n.escrowOfferBody('mr', '350')), findsOneWidget);
    });

    testWidgets('shows nothing when there is nothing to say', (tester) async {
      shows(testEscrowInfo());

      await pump(tester);

      expect(find.text(l10n.escrowTitle), findsNothing);
    });

    testWidgets('shows nothing for a request that is not hers', (tester) async {
      shows(null);

      await pump(tester);

      expect(find.text(l10n.escrowTitle), findsNothing);
    });

    testWidgets('shows nothing when the payment can not be fetched', (
      tester,
    ) async {
      when(
        () => escrow.fetchInfo('request-1'),
      ).thenAnswer((_) async => const Err(EscrowUnavailableFailure()));

      await pump(tester);

      expect(find.text(l10n.escrowTitle), findsNothing);
    });

    for (final (status, text) in <(EscrowStatus, String)>[
      (EscrowStatus.pending, l10n.escrowPendingBody),
      (EscrowStatus.held, l10n.escrowHeldBody('350')),
      (EscrowStatus.paidOut, l10n.escrowPaidOutBody),
      (EscrowStatus.disputed, l10n.escrowDisputedBody),
      (EscrowStatus.refundDue, l10n.escrowRefundDueBody),
      (EscrowStatus.refunded, l10n.escrowRefundedBody),
    ]) {
      testWidgets('says where a $status payment stands', (tester) async {
        shows(testEscrowInfo(escrow: testEscrow(status)));

        await pump(tester);

        expect(find.text(text), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
      });
    }

    for (final status in [PaymentStatus.created, PaymentStatus.pending]) {
      testWidgets('says it is checking while a $status payment is open', (
        tester,
      ) async {
        shows(testEscrowInfo(canSecure: true, paymentStatus: status));

        await pump(tester);

        expect(find.text(l10n.escrowPaymentCheckingBody), findsOneWidget);
        expect(find.text(l10n.escrowOfferBody('ms', '350')), findsNothing);
        expect(
          find.widgetWithText(FilledButton, l10n.escrowRetryAction('ms')),
          findsOneWidget,
        );
      });
    }

    for (final status in [
      PaymentStatus.failed,
      PaymentStatus.cancelled,
      PaymentStatus.expired,
    ]) {
      testWidgets('offers the payment again after a $status one', (
        tester,
      ) async {
        shows(testEscrowInfo(canSecure: true, paymentStatus: status));

        await pump(tester);

        expect(find.text(l10n.escrowPaymentCheckingBody), findsNothing);
        expect(find.text(l10n.escrowOfferBody('ms', '350')), findsOneWidget);
      });
    }

    testWidgets('shows an online payment held, with no transfer method', (
      tester,
    ) async {
      shows(
        testEscrowInfo(
          paymentStatus: PaymentStatus.succeeded,
          escrow: testEscrow(EscrowStatus.held, method: null),
        ),
      );

      await pump(tester);

      expect(find.text(l10n.escrowHeldBody('350')), findsOneWidget);
    });

    testWidgets('says why a transfer was rejected and offers to send again', (
      tester,
    ) async {
      shows(
        testEscrowInfo(
          canSecure: true,
          escrow: testEscrow(
            EscrowStatus.rejected,
            rejectReason: 'المبلغ ناقص',
          ),
        ),
      );

      await pump(tester);

      expect(
        find.text(l10n.escrowRejectedBody('المبلغ ناقص')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, l10n.escrowRetryAction('ms')),
        findsOneWidget,
      );
    });

    final release = DateTime(2026, 10, 16, 20);

    for (final (name, escrow, text)
        in <(String, Escrow, String Function(String))>[
          (
            'the technician confirmed first',
            testEscrow(
              EscrowStatus.held,
              technicianConfirmed: true,
              releaseAt: release,
            ),
            (moment) => l10n.escrowHeldTechnicianConfirmedBody('ms', moment),
          ),
          (
            'she confirmed first',
            testEscrow(EscrowStatus.held, consumerConfirmed: true),
            (_) => l10n.escrowHeldYouConfirmedBody('ms'),
          ),
          (
            'both confirmed',
            testEscrow(
              EscrowStatus.held,
              consumerConfirmed: true,
              technicianConfirmed: true,
              releaseAt: release,
            ),
            l10n.escrowHeldBothConfirmedBody,
          ),
        ]) {
      testWidgets('says where the money stands when $name', (tester) async {
        shows(testEscrowInfo(escrow: escrow));

        await pump(tester);

        expect(
          find.text(text(momentLabel(l10n, release))),
          findsOneWidget,
        );
      });
    }
  });

  group('paying in', () {
    testWidgets('opens the payment screen', (
      tester,
    ) async {
      shows(testEscrowInfo(canSecure: true));
      await pump(
        tester,
        stubRoutes: ['/consumer/requests/request-1/secure-payment'],
      );

      await tester.tap(find.text(l10n.escrowSecureAction('ms')));
      await tester.pumpAndSettle();

      expect(
        find.text('/consumer/requests/request-1/secure-payment'),
        findsOneWidget,
      );
    });
  });

  group('answering once the work is done', () {
    final held = testEscrowInfo(
      canConfirm: true,
      canDispute: true,
      escrow: testEscrow(EscrowStatus.held),
    );

    setUp(() {
      when(
        () => escrow.confirmWork('request-1'),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => escrow.dispute('request-1', any()),
      ).thenAnswer((_) async => const Ok(null));
    });

    testWidgets('confirms after asking', (tester) async {
      shows(held);
      await pump(tester);

      await tester.tap(find.text(l10n.escrowConfirmAction));
      await tester.pumpAndSettle();
      expect(find.text(l10n.escrowConfirmQuestion), findsOneWidget);
      expect(find.text(l10n.escrowConfirmNote('350')), findsOneWidget);
      await tester.tap(find.text(l10n.escrowConfirmYes));
      await tester.pumpAndSettle();

      verify(() => escrow.confirmWork('request-1')).called(1);
    });

    testWidgets('keeps the money when she changes her mind', (tester) async {
      shows(held);
      await pump(tester);

      await tester.tap(find.text(l10n.escrowConfirmAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.escrowNotNow));
      await tester.pumpAndSettle();

      verifyNever(() => escrow.confirmWork(any()));
    });

    testWidgets('disputes with the reason she writes', (tester) async {
      shows(held);
      await pump(tester);

      await tester.tap(find.text(l10n.escrowDisputeAction));
      await tester.pumpAndSettle();
      final send = find.widgetWithText(TextButton, l10n.escrowDisputeSend);
      expect(tester.widget<TextButton>(send).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '  الفني ماجاش  ');
      await tester.pump();
      await tester.tap(send);
      await tester.pumpAndSettle();

      verify(() => escrow.dispute('request-1', 'الفني ماجاش')).called(1);
    });

    testWidgets('offers no confirmation before the work is done', (
      tester,
    ) async {
      shows(
        testEscrowInfo(canDispute: true, escrow: testEscrow(EscrowStatus.held)),
      );

      await pump(tester);

      expect(find.text(l10n.escrowConfirmAction), findsNothing);
      expect(find.text(l10n.escrowDisputeAction), findsOneWidget);
    });

    testWidgets('says when the answer was refused', (tester) async {
      shows(held);
      when(
        () => escrow.confirmWork('request-1'),
      ).thenAnswer((_) async => const Err(EscrowUnavailableFailure()));
      await pump(tester);

      await tester.tap(find.text(l10n.escrowConfirmAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.escrowConfirmYes));
      await tester.pumpAndSettle();

      expect(find.text(l10n.escrowFailureUnavailable), findsOneWidget);
    });
  });

  testWidgets('reads the payment again when the server reports news', (
    tester,
  ) async {
    shows(testEscrowInfo(escrow: testEscrow(EscrowStatus.pending)));
    await pump(tester);
    expect(find.text(l10n.escrowPendingBody), findsOneWidget);

    shows(testEscrowInfo(escrow: testEscrow(EscrowStatus.held)));
    live.fire();
    await tester.pumpAndSettle();

    expect(find.text(l10n.escrowHeldBody('350')), findsOneWidget);
  });
}
