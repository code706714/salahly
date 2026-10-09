import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/router/session_redirect.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';

const _user = AuthUser(id: 'user-1');

SessionReady _readyAs(UserRole role) => SessionReady(
  user: _user,
  profile: UserProfile(
    id: _user.id,
    phone: '+201002345678',
    fullName: 'محمد أحمد',
    activeRole: role,
  ),
);

void main() {
  const screens = [
    AppRoutes.splash,
    AppRoutes.login,
    AppRoutes.otp,
    AppRoutes.welcome,
    AppRoutes.consumerOnboarding,
    AppRoutes.technicianOnboarding,
    AppRoutes.consumerHome,
    AppRoutes.technicianHome,
    AppRoutes.sessionUnavailable,
  ];
  const legalPages = [AppRoutes.legal, AppRoutes.terms, AppRoutes.privacy];

  final cases = [
    (
      name: 'loading',
      session: const SessionLoading(),
      entry: AppRoutes.splash,
      allowed: {AppRoutes.splash},
    ),
    (
      name: 'signed out',
      session: const SessionSignedOut(),
      entry: AppRoutes.login,
      allowed: {AppRoutes.login, AppRoutes.otp},
    ),
    (
      name: 'needs onboarding',
      session: const SessionNeedsOnboarding(_user),
      entry: AppRoutes.welcome,
      allowed: {
        AppRoutes.welcome,
        AppRoutes.consumerOnboarding,
        AppRoutes.technicianOnboarding,
      },
    ),
    (
      name: 'profile unavailable',
      session: const SessionProfileUnavailable(_user),
      entry: AppRoutes.sessionUnavailable,
      allowed: {AppRoutes.sessionUnavailable},
    ),
    (
      name: 'ready as a consumer',
      session: _readyAs(UserRole.consumer),
      entry: AppRoutes.consumerHome,
      allowed: {AppRoutes.consumerHome},
    ),
    (
      name: 'ready as a technician',
      session: _readyAs(UserRole.technician),
      entry: AppRoutes.technicianHome,
      allowed: {AppRoutes.technicianHome},
    ),
  ];

  group('sessionRedirect', () {
    for (final (:name, :session, :entry, :allowed) in cases) {
      group('when $name', () {
        for (final path in screens) {
          if (allowed.contains(path)) {
            test('stays on $path', () {
              expect(sessionRedirect(session, path), isNull);
            });
          } else {
            test('sends $path to $entry', () {
              expect(sessionRedirect(session, path), entry);
            });
          }
        }

        for (final path in legalPages) {
          test('stays on legal page $path', () {
            expect(sessionRedirect(session, path), isNull);
          });
        }

        test('stays on the goodbye after deleting an account', () {
          expect(sessionRedirect(session, AppRoutes.accountDeleted), isNull);
        });

        test('sends an unknown path to $entry', () {
          expect(sessionRedirect(session, '/nowhere'), entry);
        });
      });
    }

    group('path matching', () {
      test('allows screens nested under an allowed route', () {
        expect(
          sessionRedirect(_readyAs(UserRole.consumer), '/consumer/requests/7'),
          isNull,
        );
        expect(
          sessionRedirect(const SessionNeedsOnboarding(_user), '/onboarding'),
          isNull,
        );
      });

      test('does not treat a shared name prefix as nesting', () {
        expect(
          sessionRedirect(const SessionSignedOut(), '/loginx'),
          AppRoutes.login,
        );
        expect(
          sessionRedirect(_readyAs(UserRole.consumer), '/consumers'),
          AppRoutes.consumerHome,
        );
        expect(
          sessionRedirect(const SessionSignedOut(), '/legalese'),
          AppRoutes.login,
        );
      });

      test('keeps the splash screen exact while loading', () {
        expect(
          sessionRedirect(const SessionLoading(), '/login'),
          AppRoutes.splash,
        );
      });
    });
  });
}
