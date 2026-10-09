import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The app's strings, for finding the text a screen shows.
final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

/// The smallest phone the layouts must fit, in logical pixels.
const smallPhone = Size(360, 690);

/// Loads the fonts bundled with the app, so text in widget tests has real
/// metrics. The default test font draws every glyph as a one-em square,
/// which makes Arabic text far wider than on a device.
///
/// Call it from `setUpAll`, outside the fake-async zone of a widget test.
Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    final fonts = (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final font in fonts) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

extension PumpApp on WidgetTester {
  /// Pumps [page] as the first route of an app with the app's theme and
  /// Arabic localizations, on a screen of [surfaceSize].
  ///
  /// [repositories] and [blocs] sit above the app, as in `SalahlyApp`, so
  /// sheets and pushed routes can read them too. Each path in [stubRoutes]
  /// is a route that only shows its own path, so a test can check where
  /// [page] navigated.
  Future<void> pumpApp(
    Widget page, {
    List<RepositoryProvider<Object>> repositories = const [],
    List<BlocProvider<StateStreamableSource<Object?>>> blocs = const [],
    List<String> stubRoutes = const [],
    Size surfaceSize = smallPhone,
  }) async {
    view
      ..physicalSize = surfaceSize * 3
      ..devicePixelRatio = 3;
    addTearDown(view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => page),
        for (final path in stubRoutes)
          GoRoute(
            path: path,
            builder: (context, state) => Scaffold(body: Text(path)),
          ),
      ],
    );
    addTearDown(router.dispose);

    Widget app = MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
    if (blocs.isNotEmpty) {
      app = MultiBlocProvider(providers: blocs, child: app);
    }
    if (repositories.isNotEmpty) {
      app = MultiRepositoryProvider(providers: repositories, child: app);
    }
    await pumpWidget(app);
  }
}
