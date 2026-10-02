import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/splash/presentation/pages/splash_page.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

void main() {
  group('SplashPage', () {
    testWidgets('shows the app name in RTL', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SplashPage(),
        ),
      );
      await tester.pumpAndSettle();

      final name = find.text('صلحلي');
      expect(name, findsOneWidget);
      expect(
        Directionality.of(tester.element(name)),
        TextDirection.rtl,
      );
    });
  });
}
