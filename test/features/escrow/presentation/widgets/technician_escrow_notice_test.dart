import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:salahly/features/escrow/presentation/widgets/technician_escrow_notice.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';
import '../../escrow_fixtures.dart';

void main() {
  late MockEscrowRepository escrow;
  late FakeLiveUpdates live;
  late MockSessionCubit session;
  final release = DateTime(2026, 10, 16, 20);

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

  void shows(TechnicianEscrow? view) => when(
    () => escrow.fetchTechnicianEscrow('request-1'),
  ).thenAnswer((_) async => Ok(view));

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      const Scaffold(body: TechnicianEscrowNotice(requestId: 'request-1')),
      repositories: [
        RepositoryProvider<EscrowRepository>.value(value: escrow),
        RepositoryProvider<LiveUpdates>.value(value: live),
      ],
      blocs: [BlocProvider<SessionCubit>.value(value: session)],
    );
    await tester.pump();
  }

  testWidgets('shows nothing when the consumer did not pay in', (
    tester,
  ) async {
    shows(null);

    await pump(tester);

    expect(find.byType(Card), findsNothing);
    expect(find.byIcon(Icons.verified_user_outlined), findsNothing);
  });

  for (final (name, view, text)
      in <(String, TechnicianEscrow, String Function())>[
        (
          'a pending',
          testTechnicianEscrow(EscrowStatus.pending),
          () => l10n.technicianEscrowPending('350'),
        ),
        (
          'a held one before the work is finished',
          testTechnicianEscrow(EscrowStatus.held, canDispute: true),
          () => l10n.technicianEscrowHeld('350'),
        ),
        (
          'a held one he can confirm',
          testTechnicianEscrow(EscrowStatus.held, canConfirm: true),
          () => l10n.technicianEscrowFinished('350'),
        ),
        (
          'a held one the consumer confirmed',
          testTechnicianEscrow(
            EscrowStatus.held,
            canConfirm: true,
            consumerConfirmed: true,
          ),
          () => l10n.technicianEscrowConsumerConfirmed('350'),
        ),
        (
          'a held one he confirmed',
          testTechnicianEscrow(
            EscrowStatus.held,
            technicianConfirmed: true,
            releaseAt: release,
          ),
          () => l10n.technicianEscrowYouConfirmed(
            momentLabel(l10n, release),
            '350',
          ),
        ),
        (
          'a held one both confirmed',
          testTechnicianEscrow(
            EscrowStatus.held,
            consumerConfirmed: true,
            technicianConfirmed: true,
            releaseAt: release,
          ),
          () => l10n.technicianEscrowBothConfirmed(
            '350',
            momentLabel(l10n, release),
          ),
        ),
        (
          'a paid out',
          testTechnicianEscrow(EscrowStatus.paidOut),
          () => l10n.technicianEscrowPaidOut('350'),
        ),
        (
          'a disputed',
          testTechnicianEscrow(EscrowStatus.disputed),
          () => l10n.technicianEscrowDisputed,
        ),
        (
          'a refund due',
          testTechnicianEscrow(EscrowStatus.refundDue),
          () => l10n.technicianEscrowRefunded,
        ),
        (
          'a refunded',
          testTechnicianEscrow(EscrowStatus.refunded),
          () => l10n.technicianEscrowRefunded,
        ),
      ]) {
    testWidgets('says where $name payment stands', (tester) async {
      shows(view);

      await pump(tester);

      expect(find.text(text()), findsOneWidget);
    });
  }

  testWidgets('offers nothing to do once the money is in the wallet', (
    tester,
  ) async {
    shows(testTechnicianEscrow(EscrowStatus.paidOut));

    await pump(tester);

    expect(find.byType(FilledButton), findsNothing);
    expect(find.text(l10n.escrowDisputeAction), findsNothing);
  });

  group('his answer', () {
    testWidgets('confirms the work after asking', (tester) async {
      shows(testTechnicianEscrow(EscrowStatus.held, canConfirm: true));
      when(
        () => escrow.technicianConfirmWork('request-1'),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);

      await tester.tap(find.text(l10n.technicianEscrowConfirmAction));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.technicianEscrowConfirmNote('350')),
        findsOneWidget,
      );
      await tester.tap(find.text(l10n.escrowConfirmYes));
      await tester.pumpAndSettle();

      verify(() => escrow.technicianConfirmWork('request-1')).called(1);
    });

    testWidgets('does nothing when he backs out of the question', (
      tester,
    ) async {
      shows(testTechnicianEscrow(EscrowStatus.held, canConfirm: true));
      await pump(tester);

      await tester.tap(find.text(l10n.technicianEscrowConfirmAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.escrowNotNow));
      await tester.pumpAndSettle();

      verifyNever(() => escrow.technicianConfirmWork(any()));
    });

    testWidgets('has no confirm button before the work is finished', (
      tester,
    ) async {
      shows(testTechnicianEscrow(EscrowStatus.held, canDispute: true));

      await pump(tester);

      expect(find.text(l10n.technicianEscrowConfirmAction), findsNothing);
      expect(find.text(l10n.escrowDisputeAction), findsOneWidget);
    });

    testWidgets('objects with a reason', (tester) async {
      shows(
        testTechnicianEscrow(
          EscrowStatus.held,
          canConfirm: true,
          canDispute: true,
        ),
      );
      when(
        () => escrow.technicianDispute('request-1', 'العميل رفض يدفع'),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);

      await tester.tap(find.text(l10n.escrowDisputeAction));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'العميل رفض يدفع');
      await tester.pump();
      await tester.tap(find.text(l10n.escrowDisputeSend));
      await tester.pumpAndSettle();

      verify(
        () => escrow.technicianDispute('request-1', 'العميل رفض يدفع'),
      ).called(1);
    });

    testWidgets('says why an answer was refused', (tester) async {
      shows(testTechnicianEscrow(EscrowStatus.held, canConfirm: true));
      when(
        () => escrow.technicianConfirmWork('request-1'),
      ).thenAnswer((_) async => const Err(EscrowUnavailableFailure()));
      await pump(tester);

      await tester.tap(find.text(l10n.technicianEscrowConfirmAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.escrowConfirmYes));
      await tester.pumpAndSettle();

      expect(find.text(l10n.escrowFailureUnavailable), findsOneWidget);
    });
  });

  testWidgets('reads the payment again when the server reports news', (
    tester,
  ) async {
    shows(testTechnicianEscrow(EscrowStatus.pending));
    await pump(tester);

    shows(testTechnicianEscrow(EscrowStatus.held));
    live.fire();
    await tester.pumpAndSettle();

    expect(find.text(l10n.technicianEscrowHeld('350')), findsOneWidget);
  });
}
