import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_router.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class SalahlyApp extends StatefulWidget {
  const SalahlyApp({super.key});

  @override
  State<SalahlyApp> createState() => _SalahlyAppState();
}

class _SalahlyAppState extends State<SalahlyApp> {
  late final GoRouter _router = createRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      theme: AppTheme.light(),
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
    );
  }
}
