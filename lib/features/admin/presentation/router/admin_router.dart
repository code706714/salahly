import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/pages/admin_checking_page.dart';
import 'package:salahly/features/admin/presentation/pages/admin_login_page.dart';
import 'package:salahly/features/admin/presentation/pages/admin_unavailable_page.dart';
import 'package:salahly/features/admin/presentation/pages/audit_page.dart';
import 'package:salahly/features/admin/presentation/pages/no_access_page.dart';
import 'package:salahly/features/admin/presentation/pages/overview_page.dart';
import 'package:salahly/features/admin/presentation/pages/requests_page.dart';
import 'package:salahly/features/admin/presentation/pages/settings_page.dart';
import 'package:salahly/features/admin/presentation/pages/topups_page.dart';
import 'package:salahly/features/admin/presentation/pages/users_page.dart';
import 'package:salahly/features/admin/presentation/pages/verification_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_shell.dart';

/// Where [state] lets the person be. The console's pages open only once the
/// server accepted the person as an admin, whatever address was typed; every
/// other state has one screen, and an address that is not one of the
/// console's goes to the overview.
///
/// The server checks every call again, so this keeps the screens tidy but is
/// not what protects the data.
String? adminRedirect(AdminSessionState state, String path) {
  final screen = switch (state) {
    AdminSessionChecking() => AdminRoutes.checking,
    AdminSessionSignedOut() => AdminRoutes.login,
    AdminSessionNoAccess() => AdminRoutes.noAccess,
    AdminSessionUnavailable() => AdminRoutes.unavailable,
    AdminSessionReady() => null,
  };
  if (screen != null) return path == screen ? null : screen;
  return AdminRoutes.console.contains(path) ? null : AdminRoutes.overview;
}

GoRouter createAdminRouter(
  AdminSessionCubit session, {
  required Listenable refresh,
}) {
  Page<void> page(Widget child) => NoTransitionPage<void>(child: child);

  return GoRouter(
    initialLocation: AdminRoutes.checking,
    refreshListenable: refresh,
    redirect: (context, state) => adminRedirect(session.state, state.uri.path),
    routes: [
      GoRoute(
        path: AdminRoutes.checking,
        pageBuilder: (context, state) => page(const AdminCheckingPage()),
      ),
      GoRoute(
        path: AdminRoutes.login,
        pageBuilder: (context, state) => page(const AdminLoginPage()),
      ),
      GoRoute(
        path: AdminRoutes.noAccess,
        pageBuilder: (context, state) => page(const NoAccessPage()),
      ),
      GoRoute(
        path: AdminRoutes.unavailable,
        pageBuilder: (context, state) => page(
          switch (session.state) {
            AdminSessionUnavailable(:final failure) => AdminUnavailablePage(
              failure: failure,
            ),
            _ => const AdminCheckingPage(),
          },
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider(
          create: (context) {
            final cubit = OverviewCubit(context.read());
            unawaited(cubit.load());
            return cubit;
          },
          child: AdminShell(child: child),
        ),
        routes: [
          GoRoute(
            path: AdminRoutes.overview,
            pageBuilder: (context, state) => page(const OverviewPage()),
          ),
          GoRoute(
            path: AdminRoutes.verification,
            pageBuilder: (context, state) => page(const VerificationPage()),
          ),
          GoRoute(
            path: AdminRoutes.transfers,
            pageBuilder: (context, state) => page(const TopupsPage()),
          ),
          GoRoute(
            path: AdminRoutes.requests,
            pageBuilder: (context, state) => page(const RequestsPage()),
          ),
          GoRoute(
            path: AdminRoutes.users,
            pageBuilder: (context, state) => page(const UsersPage()),
          ),
          GoRoute(
            path: AdminRoutes.settings,
            pageBuilder: (context, state) => page(const SettingsPage()),
          ),
          GoRoute(
            path: AdminRoutes.audit,
            pageBuilder: (context, state) => page(const AuditPage()),
          ),
        ],
      ),
    ],
  );
}
