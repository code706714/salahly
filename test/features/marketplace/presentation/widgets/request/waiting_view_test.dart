import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/waiting_view.dart';

import '../../../../../helpers/request_views_fixtures.dart';
import '../../../../../helpers/request_views_harness.dart';
import '../../../../../pump_app.dart';

void main() {
  late ConsumerViewHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() => harness = ConsumerViewHarness());

  Future<void> pumpView(WidgetTester tester) => harness.pump(
    tester,
    WaitingView(details: harness.request.state.details!),
  );

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('shows', () {
    testWidgets('who the request went to and how far it got', (tester) async {
      harness.show(liveRequest(issue: RequestIssue.needsCleaning));

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('تنظيف تكييف'), findsOneWidget);
      expect(find.text('بكره · الضهر 12 لـ 3'), findsOneWidget);
      expect(find.text(l10n.waitingTitle), findsOneWidget);
      expect(
        find.text(
          'طلبك راح لـ 5 فنيين موثّقين قريبين منك. '
          'مش لازم تفضلي فاتحة الأبلكيشن: أول ما يوصل عرض هتلاقيه هنا '
          'وفي طلباتك.',
        ),
        findsOneWidget,
      );
      expect(find.text('الطلب اتبعت من 40 دقيقة'), findsOneWidget);
      expect(find.text('3 فنيين شافوه'), findsOneWidget);
      expect(find.text(l10n.waitingNoOffers), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      expect(find.text(l10n.waitingWidenTitle), findsOneWidget);
      expect(find.text(l10n.waitingWidenBody), findsOneWidget);
      expect(
        find.text('وسّعي المعاد عشان العروض تيجي أسرع'),
        findsOneWidget,
      );
      expect(find.text(l10n.waitingCancel), findsOneWidget);
      expect(find.text(l10n.waitingCancelFree), findsOneWidget);
    });

    testWidgets('that no technician is free yet, and nobody saw it', (
      tester,
    ) async {
      harness.show(
        liveRequest(sentTo: 0, seenBy: 0, sentAgo: const Duration(hours: 3)),
      );

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining(l10n.waitingSentTo(0)), findsOneWidget);
      expect(find.text('الطلب اتبعت من 3 ساعات'), findsOneWidget);
      expect(find.text(l10n.waitingSeenBy(0)), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('that it went to technicians further away', (tester) async {
      harness.show(liveRequest(widened: true));

      await pumpView(tester);

      expect(find.text(l10n.waitingWidenedTitle), findsOneWidget);
      expect(find.text(l10n.waitingWidenedBody), findsOneWidget);
      expect(find.text(l10n.waitingWidenTitle), findsNothing);
    });

    testWidgets('that the time was widened, instead of widening it', (
      tester,
    ) async {
      harness.show(liveRequest(window: RequestWindow.anyTime));

      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('بكره · أي وقت 9 لـ 9'), findsOneWidget);
      expect(find.text(l10n.waitingWindowWidened('ms')), findsOneWidget);
      expect(find.text(l10n.waitingWidenWindow('ms')), findsNothing);
    });

    testWidgets('the weekday of a later day', (tester) async {
      final day = dayFromToday(3);
      harness.show(liveRequest(day: day));

      await pumpView(tester);

      expect(find.text('${weekdayName(day)} · الضهر 12 لـ 3'), findsOneWidget);
    });

    testWidgets('the problem alone until the categories load', (tester) async {
      when(() => harness.categories.state).thenReturn(const CategoriesState());
      harness.show(liveRequest());

      await pumpView(tester);

      expect(find.text('مش بيبرّد'), findsOneWidget);
    });

    testWidgets('his words to a man', (tester) async {
      harness = ConsumerViewHarness(honorific: Honorific.mr)
        ..show(liveRequest());

      await pumpView(tester);

      expect(find.text('وسّع المعاد عشان العروض تيجي أسرع'), findsOneWidget);
      expect(
        find.textContaining('مش لازم تفضل فاتح الأبلكيشن'),
        findsOneWidget,
      );
    });
  });

  group('widening the time', () {
    testWidgets('asks first, then widens it', (tester) async {
      harness.show(liveRequest());
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.waitingWidenWindow('ms')));
      expect(find.text(l10n.waitingWidenConfirmTitle('ms')), findsOneWidget);
      expect(
        find.text(
          'الفنيين هيقدروا ييجوا بكره في أي وقت من 9 الصبح لـ 9 بالليل.',
        ),
        findsOneWidget,
      );
      await tapAndSettle(tester, find.text(l10n.waitingWidenConfirm('ms')));

      verify(() => harness.request.widenWindow()).called(1);
    });

    testWidgets('keeps the time when she changes her mind', (tester) async {
      harness.show(liveRequest());
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.waitingWidenWindow('ms')));
      await tapAndSettle(tester, find.text(l10n.waitingKeepWindow('ms')));

      expect(find.text(l10n.waitingWidenConfirmTitle('ms')), findsNothing);
      verifyNever(() => harness.request.widenWindow());
    });

    testWidgets('shows the progress and holds the other actions', (
      tester,
    ) async {
      harness.show(liveRequest(), busy: RequestAction.widenWindow);
      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.waitingWidenWindow('ms')), findsNothing);
      final cancel = tester.widget<TextButton>(
        find.ancestor(
          of: find.text(l10n.waitingCancel),
          matching: find.byType(TextButton),
        ),
      );
      expect(cancel.onPressed, isNull);
    });
  });

  group('cancelling', () {
    testWidgets('asks first, then cancels', (tester) async {
      harness.show(liveRequest());
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.waitingCancel));
      expect(find.text(l10n.waitingCancelConfirmTitle), findsOneWidget);
      expect(find.text(l10n.waitingCancelConfirmBody), findsOneWidget);
      await tapAndSettle(tester, find.text(l10n.waitingCancel).last);

      verify(() => harness.request.cancel()).called(1);
    });

    testWidgets('keeps the request when she changes her mind', (
      tester,
    ) async {
      harness.show(liveRequest());
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.waitingCancel));
      await tapAndSettle(tester, find.text('لأ، سيبيه'));

      verifyNever(() => harness.request.cancel());
    });

    testWidgets('asks a man in his words', (tester) async {
      harness = ConsumerViewHarness(honorific: Honorific.mr)
        ..show(liveRequest());
      await pumpView(tester);

      await tapAndSettle(tester, find.text(l10n.waitingCancel));

      expect(find.text('لأ، سيبه'), findsOneWidget);
    });

    testWidgets('shows the progress and holds widening', (tester) async {
      harness.show(liveRequest(), busy: RequestAction.cancel);
      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.waitingCancel), findsNothing);
      final widen = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text(l10n.waitingWidenWindow('ms')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(widen.onPressed, isNull);
    });
  });
}
