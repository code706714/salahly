import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:salahly/features/escrow/presentation/widgets/technician_escrow_notice.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockEscrowRepository escrow;
  late FakeLiveUpdates live;

  setUpAll(loadAppFonts);

  setUp(() {
    escrow = MockEscrowRepository();
    live = FakeLiveUpdates();
  });

  void shows(EscrowStatus? status) =>
      when(
        () => escrow.fetchTechnicianEscrow('request-1'),
      ).thenAnswer(
        (_) async => Ok(
          status == null
              ? null
              : TechnicianEscrow(status: status, amountPiastres: 35000),
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      const Scaffold(body: TechnicianEscrowNotice(requestId: 'request-1')),
      repositories: [
        RepositoryProvider<EscrowRepository>.value(value: escrow),
        RepositoryProvider<LiveUpdates>.value(value: live),
      ],
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

  for (final (status, text) in <(EscrowStatus, String)>[
    (EscrowStatus.pending, l10n.technicianEscrowPending('350')),
    (EscrowStatus.held, l10n.technicianEscrowHeld('350')),
    (EscrowStatus.released, l10n.technicianEscrowReleased('350')),
    (EscrowStatus.paidOut, l10n.technicianEscrowPaidOut('350')),
    (EscrowStatus.disputed, l10n.technicianEscrowDisputed),
    (EscrowStatus.refundDue, l10n.technicianEscrowRefunded),
    (EscrowStatus.refunded, l10n.technicianEscrowRefunded),
  ]) {
    testWidgets('says where a $status payment stands', (tester) async {
      shows(status);

      await pump(tester);

      expect(find.text(text), findsOneWidget);
    });
  }

  for (final status in [EscrowStatus.held, EscrowStatus.released]) {
    testWidgets('reminds him to set his payout account when $status', (
      tester,
    ) async {
      shows(status);

      await pump(tester);

      expect(find.text(l10n.technicianEscrowNoPayout), findsOneWidget);
    });
  }

  testWidgets('does not remind him once he was paid', (tester) async {
    shows(EscrowStatus.paidOut);

    await pump(tester);

    expect(find.text(l10n.technicianEscrowNoPayout), findsNothing);
  });

  testWidgets('reads the payment again when the server reports news', (
    tester,
  ) async {
    shows(EscrowStatus.pending);
    await pump(tester);

    shows(EscrowStatus.held);
    live.fire();
    await tester.pumpAndSettle();

    expect(find.text(l10n.technicianEscrowHeld('350')), findsOneWidget);
  });
}
