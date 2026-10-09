import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/core/widgets/offline_banner.dart';
import 'package:salahly/core/widgets/segmented_tabs.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

import '../../helpers/mocks.dart';
import '../../pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpApp(Scaffold(body: Center(child: child)));

  testWidgets('a pill takes the colors of its tone', (tester) async {
    await pump(
      tester,
      const StatusPill(
        label: 'متأخر 12 يوم',
        tone: PillTone.danger,
        icon: Icons.warning_amber_rounded,
      ),
    );

    final text = tester.widget<Text>(find.text('متأخر 12 يوم'));
    expect(text.style?.color, AppColors.light.dangerDeep);
    final box = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('متأخر 12 يوم'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect((box.decoration as BoxDecoration).color, AppColors.light.dangerSoft);
  });

  testWidgets('a WhatsApp button is green and tappable', (tester) async {
    var taps = 0;
    await pump(
      tester,
      WhatsAppButton(label: 'ابعت تأكيد', onPressed: () => taps++),
    );

    await tester.tap(find.text('ابعت تأكيد'));

    expect(taps, 1);
    expect(
      tester
          .widget<Material>(
            find
                .ancestor(
                  of: find.text('ابعت تأكيد'),
                  matching: find.byType(Material),
                )
                .first,
          )
          .color,
      AppColors.light.whatsapp,
    );
  });

  testWidgets('segmented tabs report the tab tapped', (tester) async {
    int? picked;
    await pump(
      tester,
      SegmentedTabs(
        labels: const ['الجاية (5)', 'متابعة (4)', 'خلصت'],
        selected: 0,
        onSelected: (index) => picked = index,
      ),
    );

    await tester.tap(find.text('خلصت'));

    expect(picked, 2);
    expect(
      tester.getSemantics(find.text('الجاية (5)')),
      matchesSemantics(
        label: 'الجاية (5)',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
  });

  testWidgets('an avatar shows the initials without the title', (
    tester,
  ) async {
    await pump(tester, const InitialsAvatar(name: 'م. شريف عادل'));

    expect(find.text('ش ع'), findsOneWidget);
  });

  testWidgets('money shows grouped pounds and the currency', (tester) async {
    await pump(tester, const MoneyText(385000, style: TextStyle()));

    expect(
      find.text('3,850 ${l10n.currencyEgp}', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('the detail header goes back', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
          routes: [
            GoRoute(
              path: 'detail',
              builder: (context, state) => const Scaffold(
                appBar: DetailHeader(title: 'عرض السعر', subtitle: 'م. شريف'),
              ),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
    unawaited(router.push('/detail'));
    await tester.pumpAndSettle();
    expect(find.text('عرض السعر'), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.back));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  group('offline banner', () {
    late MockSyncCubit sync;

    setUp(() => sync = MockSyncCubit());

    Future<void> pumpBanner(WidgetTester tester) => tester.pumpApp(
      const Scaffold(body: OfflineBanner()),
      blocs: [BlocProvider<SyncCubit>.value(value: sync)],
    );

    testWidgets('is hidden while the server is reachable', (tester) async {
      when(() => sync.state).thenReturn(const SyncState(pendingChanges: 3));
      await pumpBanner(tester);

      expect(find.byType(Container), findsNothing);
    });

    testWidgets('counts what waits to be sent while offline', (tester) async {
      when(
        () => sync.state,
      ).thenReturn(const SyncState(hasNetwork: false, pendingChanges: 3));
      await pumpBanner(tester);

      expect(
        find.textContaining(l10n.offlinePending(3), findRichText: true),
        findsOneWidget,
      );
      expect(l10n.offlinePending(3), startsWith('3 حاجات'));
    });

    testWidgets('shows when the server is unreachable on a network', (
      tester,
    ) async {
      when(() => sync.state).thenReturn(
        const SyncState(problem: SyncProblem.unreachable),
      );
      await pumpBanner(tester);

      expect(
        find.textContaining(l10n.offlineTitle, findRichText: true),
        findsOneWidget,
      );
    });
  });
}
