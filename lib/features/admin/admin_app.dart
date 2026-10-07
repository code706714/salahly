import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/session_refresh.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/admin/admin_dependencies.dart';
import 'package:salahly/features/admin/presentation/admin_theme.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/router/admin_router.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The team's console: Arabic, right to left, in the app's own theme.
class AdminApp extends StatefulWidget {
  const AdminApp({required this.dependencies, super.key});

  final AdminDependencies dependencies;

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final AdminSessionCubit _session = AdminSessionCubit(
    authRepository: widget.dependencies.authRepository,
    overviewRepository: widget.dependencies.overviewRepository,
  );
  late final SessionRefresh _refresh = SessionRefresh(_session.stream);
  late final GoRouter _router = createAdminRouter(_session, refresh: _refresh);
  late final ClockCubit _clock = ClockCubit()..start();

  @override
  void dispose() {
    _router.dispose();
    _refresh.dispose();
    unawaited(_session.close());
    unawaited(_clock.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.dependencies;
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: dependencies.authRepository),
        RepositoryProvider.value(value: dependencies.overviewRepository),
        RepositoryProvider.value(value: dependencies.verificationRepository),
        RepositoryProvider.value(value: dependencies.topupReviewRepository),
        RepositoryProvider.value(value: dependencies.requestsRepository),
        RepositoryProvider.value(value: dependencies.usersRepository),
        RepositoryProvider.value(value: dependencies.settingsRepository),
        RepositoryProvider.value(value: dependencies.auditRepository),
        RepositoryProvider.value(value: dependencies.filesRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _session),
          BlocProvider.value(value: _clock),
        ],
        child: MaterialApp.router(
          routerConfig: _router,
          theme: adminTheme(),
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context).adminTitle,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
