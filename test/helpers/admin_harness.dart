import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/domain/repositories/audit_repository.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/admin/presentation/admin_theme.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_shell.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

import 'admin_fixtures.dart';
import 'admin_mocks.dart';
import 'mocks.dart';

/// The console's repositories as mocks, with the overview already stubbed,
/// and a way to put a page in the console's frame.
class AdminHarness {
  AdminHarness() {
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => Ok(testOverview()));
    when(
      () => overview.fetchAreas(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => Ok(testCoverage()));
    when(() => auth.currentUser).thenReturn(
      const AuthUser(id: 'admin-1', phone: '+201001234567'),
    );
    when(() => auth.userChanges).thenAnswer((_) => const Stream.empty());
    when(auth.signOut).thenAnswer((_) async {});
  }

  /// Teaches mocktail the argument types the repositories take. Call it
  /// from `setUpAll`.
  static void registerFallbacks() {
    registerFallbackValue(OverviewPeriod.today);
    registerFallbackValue(VerificationStatus.pending);
    registerFallbackValue(const RequestFilter());
    registerFallbackValue(ComplaintFilter.open);
    registerFallbackValue(const UserFilter());
    registerFallbackValue(const AuditFilter());
    registerFallbackValue(AdminBucket.transferProofs);
    registerFallbackValue(
      const CreditPackDraft(
        role: UserRole.consumer,
        uses: 1,
        pricePiastres: 100,
      ),
    );
    registerFallbackValue(
      const AreaDraft(
        id: 'area',
        name: 'منطقة',
        city: 'مدينة',
        centerLat: 30,
        centerLng: 31,
      ),
    );
    registerFallbackValue(
      const PaymentAccountSetting(
        method: TopupMethod.wallet,
        account: '0',
        holderName: 'a',
        isActive: true,
      ),
    );
  }

  final auth = MockAuthRepository();
  final overview = MockOverviewRepository();
  final verification = MockVerificationRepository();
  final topups = MockTopupReviewRepository();
  final requests = MockRequestsRepository();
  final users = MockUsersRepository();
  final settings = MockSettingsRepository();
  final audit = MockAuditRepository();
  final files = MockAdminFilesRepository();

  /// The signed-in admin's session, as the console's gate holds it.
  AdminSessionCubit session() => AdminSessionCubit(
    authRepository: auth,
    overviewRepository: overview,
  );

  List<RepositoryProvider<Object>> get repositories => [
    RepositoryProvider<AuthRepository>.value(value: auth),
    RepositoryProvider<OverviewRepository>.value(value: overview),
    RepositoryProvider<VerificationRepository>.value(value: verification),
    RepositoryProvider<TopupReviewRepository>.value(value: topups),
    RepositoryProvider<RequestsRepository>.value(value: requests),
    RepositoryProvider<UsersRepository>.value(value: users),
    RepositoryProvider<SettingsRepository>.value(value: settings),
    RepositoryProvider<AuditRepository>.value(value: audit),
    RepositoryProvider<AdminFilesRepository>.value(value: files),
  ];

  /// Pumps [page] at [path] inside the console's frame on a desktop screen.
  Future<void> pump(
    WidgetTester tester,
    Widget page, {
    String path = AdminRoutes.overview,
    Size size = const Size(1440, 900),
    bool settle = true,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sessionCubit = session();
    addTearDown(sessionCubit.close);
    final overviewCubit = OverviewCubit(overview);
    addTearDown(overviewCubit.close);
    unawaited(overviewCubit.load());
    final clock = ClockCubit(clock: () => adminNow);
    addTearDown(clock.close);

    final router = GoRouter(
      initialLocation: path,
      routes: [
        ShellRoute(
          builder: (context, state, child) => BlocProvider.value(
            value: overviewCubit,
            child: AdminShell(child: child),
          ),
          routes: [
            GoRoute(path: path, builder: (context, state) => page),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: repositories,
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: sessionCubit),
            BlocProvider.value(value: clock),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: adminTheme(),
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    }
  }
}
