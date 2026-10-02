import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/app_dependencies.dart';
import 'package:salahly/core/router/app_router.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class SalahlyApp extends StatefulWidget {
  const SalahlyApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  State<SalahlyApp> createState() => _SalahlyAppState();
}

class _SalahlyAppState extends State<SalahlyApp> {
  late final SessionCubit _session = SessionCubit(
    authRepository: widget.dependencies.authRepository,
    accountRepository: widget.dependencies.accountRepository,
    userData: widget.dependencies.userData,
  );
  late final SessionRefresh _refresh = SessionRefresh(_session.stream);
  late final GoRouter _router = createRouter(_session, refresh: _refresh);

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    unawaited(_session.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: dependencies.authRepository),
        RepositoryProvider.value(value: dependencies.accountRepository),
        RepositoryProvider.value(value: dependencies.catalogRepository),
        RepositoryProvider.value(value: dependencies.onboardingRepository),
        RepositoryProvider.value(value: dependencies.locationService),
        RepositoryProvider.value(value: dependencies.photoPicker),
      ],
      child: BlocProvider.value(
        value: _session,
        child: MaterialApp.router(
          routerConfig: _router,
          theme: AppTheme.light(),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context).appName,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
