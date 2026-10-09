import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_thread_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/offer_thread_sheet.dart';

import '../../../../pump_app.dart';

void main() {
  const talk = OfferTalk(
    offerId: 'offer-1',
    requestId: 'request-1',
    status: OfferStatus.withdrawn,
    pricePiastres: 32000,
    awaiting: OfferTurn.consumer,
    countersLeft: 2,
    revisionsLeft: 1,
  );
  final thread = OfferThread(
    state: talk,
    events: [
      for (final (kind, actor, price) in [
        (OfferEventKind.offer, UserRole.technician, 35000),
        (OfferEventKind.counter, UserRole.consumer, 30000),
        (OfferEventKind.revise, UserRole.technician, 32000),
        (OfferEventKind.acceptCounter, UserRole.technician, 30000),
        (OfferEventKind.withdraw, UserRole.technician, null),
      ])
        OfferEvent(
          kind: kind,
          actor: actor,
          pricePiastres: price,
          createdAt: DateTime(2026, 10, 2, 20),
        ),
    ],
  );

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  Future<void> open(
    WidgetTester tester,
    Future<Result<OfferThread?>> Function() fetch, {
    UserRole viewer = UserRole.consumer,
    String honorific = 'ms',
  }) async {
    await tester.pumpApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showOfferThreadSheet(
            context,
            fetch: fetch,
            viewer: viewer,
            honorific: honorific,
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('reads the talk to the consumer, oldest step first', (
    tester,
  ) async {
    await open(tester, () async => Ok(thread));

    expect(find.text(l10n.offerThreadTitle), findsOneWidget);
    final texts = [
      l10n.threadConsumerOffer('350 ج.م'),
      l10n.threadConsumerCounter('ms', '300 ج.م'),
      l10n.threadConsumerRevise('320 ج.م'),
      l10n.threadConsumerAccept('300 ج.م'),
      l10n.threadConsumerWithdraw,
    ];
    for (final text in texts) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    final tops = [
      for (final text in texts) tester.getTopLeft(find.text(text)).dy,
    ];
    expect(tops, [...tops]..sort());
  });

  testWidgets('reads the same talk to the technician in his words', (
    tester,
  ) async {
    await open(tester, () async => Ok(thread), viewer: UserRole.technician);

    expect(find.text(l10n.threadTechnicianOffer('350 ج.م')), findsOneWidget);
    expect(find.text(l10n.threadTechnicianCounter('300 ج.م')), findsOneWidget);
    expect(find.text(l10n.threadTechnicianRevise('320 ج.م')), findsOneWidget);
    expect(find.text(l10n.threadTechnicianAccept('300 ج.م')), findsOneWidget);
    expect(find.text(l10n.threadTechnicianWithdraw), findsOneWidget);
  });

  testWidgets('says when the offer is not theirs', (tester) async {
    await open(tester, () async => const Ok(null));

    expect(find.text(l10n.marketplaceNotFound), findsOneWidget);
    expect(find.text(l10n.retry), findsNothing);
  });

  testWidgets('says why it could not be fetched, and tries again', (
    tester,
  ) async {
    final answers = <Result<OfferThread?>>[
      const Err(NetworkFailure()),
      Ok(thread),
    ];
    await open(tester, () async => answers.removeAt(0));

    expect(find.text(l10n.offerThreadFailed), findsOneWidget);

    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text(l10n.offerThreadFailed), findsNothing);
    expect(find.text(l10n.threadConsumerOffer('350 ج.م')), findsOneWidget);
  });

  testWidgets('waits while it is fetched', (tester) async {
    await tester.pumpApp(
      BlocProvider(
        create: (_) => OfferThreadCubit(fetch: () async => Ok(thread)),
        child: const OfferThreadView(viewer: UserRole.consumer),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
