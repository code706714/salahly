import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/price_change_view.dart';

import '../../../../../helpers/follow_up_harness.dart';
import '../../../../../helpers/marketplace_fixtures.dart';
import '../../../../../pump_app.dart';

void main() {
  late FollowUpHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
  });

  setUp(() => harness = FollowUpHarness());

  final details = testRequestDetails(job: testPriceChangeJob());

  Future<void> pump(WidgetTester tester, {RequestAction? busy}) {
    when(() => harness.request.state).thenReturn(
      RequestState(
        status: RequestLoadStatus.ready,
        details: details,
        busy: busy,
      ),
    );
    return harness.pump(tester, PriceChangeView(details: details));
  }

  testWidgets('shows the agreed and the new lines and the new total', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.priceChangeTitle('محمود')), findsOneWidget);
    expect(
      find.text(l10n.priceChangeAgreedLine('كشف وتنظيف')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.priceChangeNewLine('شحن فريون جزئي')),
      findsOneWidget,
    );
    expect(find.text('350'), findsOneWidget);
    expect(find.text('300'), findsOneWidget);
    expect(find.text(l10n.priceChangeNewTotal), findsOneWidget);
    expect(find.text(l10n.pounds('650')), findsOneWidget);
    expect(find.text(l10n.priceChangeShield('ms', '350')), findsOneWidget);
    expect(find.text(l10n.priceChangeApprove('650')), findsOneWidget);
  });

  testWidgets('speaks to a man as a man', (tester) async {
    harness = FollowUpHarness(honorific: Honorific.mr);
    await pump(tester);

    expect(find.text(l10n.priceChangeShield('mr', '350')), findsOneWidget);
    expect(find.text(l10n.priceChangeDecline('mr')), findsOneWidget);
    expect(find.text(l10n.priceChangeCall('mr')), findsOneWidget);
  });

  testWidgets('approves the new price and says so', (tester) async {
    when(
      () => harness.request.answerPriceChange(approve: true),
    ).thenAnswer((_) async => true);
    await pump(tester);

    await tester.tap(find.text(l10n.priceChangeApprove('650')));
    await tester.pump();

    verify(() => harness.request.answerPriceChange(approve: true)).called(1);
    expect(
      find.text(l10n.priceChangeApproved('ms', '650', 'محمود')),
      findsOneWidget,
    );
  });

  testWidgets('says nothing when approving failed', (tester) async {
    when(
      () => harness.request.answerPriceChange(approve: true),
    ).thenAnswer((_) async => false);
    await pump(tester);

    await tester.tap(find.text(l10n.priceChangeApprove('650')));
    await tester.pump();

    expect(
      find.text(l10n.priceChangeApproved('ms', '650', 'محمود')),
      findsNothing,
    );
  });

  testWidgets('declines after confirming', (tester) async {
    when(
      () => harness.request.answerPriceChange(approve: false),
    ).thenAnswer((_) async => true);
    await pump(tester);

    await tester.tap(find.text(l10n.priceChangeDecline('ms')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.priceChangeDeclineQuestion('ms')), findsOneWidget);
    expect(find.text(l10n.priceChangeDeclineBody('ms', '350')), findsOneWidget);
    await tester.tap(find.text(l10n.priceChangeDecline('ms')).last);
    await tester.pumpAndSettle();

    verify(() => harness.request.answerPriceChange(approve: false)).called(1);
    expect(
      find.text(l10n.priceChangeDeclined('ms', '350', 'محمود')),
      findsOneWidget,
    );
  });

  testWidgets('keeps the question open when declining is called off', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text(l10n.priceChangeDecline('ms')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.back));
    await tester.pumpAndSettle();

    verifyNever(
      () => harness.request.answerPriceChange(approve: any(named: 'approve')),
    );
  });

  testWidgets('calls the technician first', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.priceChangeCall('ms')));
    await tester.pump();

    verify(
      () => harness.apps.dial(PhoneNumber.tryParse('+201009990041')!),
    ).called(1);
  });

  group('while answering', () {
    testWidgets('shows the approval in progress', (tester) async {
      await pump(tester, busy: RequestAction.approvePrice);

      expect(find.text(l10n.priceChangeApprove('650')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text(l10n.priceChangeDecline('ms')));
      await tester.pump();
      expect(find.text(l10n.priceChangeDeclineQuestion('ms')), findsNothing);
    });

    testWidgets('shows the decline in progress', (tester) async {
      await pump(tester, busy: RequestAction.declinePrice);

      expect(find.text(l10n.priceChangeDecline('ms')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.text(l10n.priceChangeApprove('650')));
      await tester.pump();
      verifyNever(
        () => harness.request.answerPriceChange(approve: any(named: 'approve')),
      );
    });
  });

  testWidgets('lists a line bought more than once with its quantity', (
    tester,
  ) async {
    final job = testRequestJob(
      quoteStatus: testPriceChangeJob().quoteStatus,
      quoteSentAt: DateTime(2026, 10, 3, 12, 35),
      items: const [
        PriceLine(
          title: 'كشف وتنظيف',
          unitPricePiastres: 35000,
          quantity: 1,
          addedLater: false,
        ),
        PriceLine(
          title: 'فلتر',
          unitPricePiastres: 5000,
          quantity: 2,
          addedLater: true,
        ),
      ],
    );
    final withQuantity = testRequestDetails(job: job);
    when(() => harness.request.state).thenReturn(
      RequestState(status: RequestLoadStatus.ready, details: withQuantity),
    );
    await harness.pump(tester, PriceChangeView(details: withQuantity));

    expect(find.text(l10n.priceChangeNewLine('فلتر × 2')), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text(l10n.pounds('450')), findsOneWidget);
  });
}
