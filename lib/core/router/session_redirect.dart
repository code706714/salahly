import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';

/// Where [path] should send the user in [session], or null to stay.
///
/// Each session state owns a set of screens; anything outside that set
/// redirects to the state's entry screen. Legal pages and the goodbye after
/// deleting an account are always open.
String? sessionRedirect(SessionState session, String path) {
  bool isUnder(String route) => path == route || path.startsWith('$route/');

  if (isUnder(AppRoutes.legal) || path == AppRoutes.accountDeleted) {
    return null;
  }
  final (allowed, entry) = switch (session) {
    SessionLoading() => (path == AppRoutes.splash, AppRoutes.splash),
    SessionSignedOut() => (isUnder(AppRoutes.login), AppRoutes.login),
    SessionProfileUnavailable() => (
      path == AppRoutes.sessionUnavailable,
      AppRoutes.sessionUnavailable,
    ),
    SessionNeedsOnboarding() => (
      path == AppRoutes.welcome || isUnder(AppRoutes.onboarding),
      AppRoutes.welcome,
    ),
    SessionReady(:final profile) => switch (profile.activeRole) {
      UserRole.consumer => (
        isUnder(AppRoutes.consumerHome),
        AppRoutes.consumerHome,
      ),
      UserRole.technician => (
        isUnder(AppRoutes.technicianHome),
        AppRoutes.technicianHome,
      ),
    },
  };
  return allowed ? null : entry;
}
