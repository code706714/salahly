import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/admin/admin_app.dart';
import 'package:salahly/features/admin/admin_dependencies.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/admin/presentation/router/admin_router.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';

import '../../../helpers/admin_fixtures.dart';
import '../../../helpers/admin_harness.dart';
import '../../../pump_app.dart';

void main() {
  late AdminHarness h;
  late StreamController<AuthUser?> users;

  const admin = AuthUser(id: 'admin-1', phone: '+201001234567');

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    AdminHarness.registerFallbacks();
    registerFallbackValue(PhoneNumber.tryParse('1002345678'));
    registerFallbackValue(OtpChannel.whatsapp);
  });

  setUp(() {
    h = AdminHarness();
    users = StreamController<AuthUser?>.broadcast();
    addTearDown(users.close);
    when(() => h.auth.userChanges).thenAnswer((_) => users.stream);
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      AdminApp(
        dependencies: AdminDependencies(
          authRepository: h.auth,
          overviewRepository: h.overview,
          verificationRepository: h.verification,
          topupReviewRepository: h.topups,
          requestsRepository: h.requests,
          usersRepository: h.users,
          settingsRepository: h.settings,
          auditRepository: h.audit,
          filesRepository: h.files,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> signIn(WidgetTester tester) async {
    users.add(admin);
    await tester.pumpAndSettle();
  }

  group('before sign in', () {
    testWidgets('asks the server nothing while nobody is signed in', (
      tester,
    ) async {
      await pumpApp(tester);

      users.add(null);
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminLoginTitle), findsOneWidget);
      verifyNever(() => h.overview.fetchOverview(any()));
    });

    testWidgets('shows that it is checking until the server answers', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.text(l10n.adminChecking), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('sends a code to the number typed', (tester) async {
      when(
        () => h.auth.requestOtp(
          phone: any(named: 'phone'),
          channel: any(named: 'channel'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      await pumpApp(tester);
      users.add(null);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1001234567');
      await tester.tap(find.text(l10n.phoneSendWhatsapp));
      await tester.pumpAndSettle();

      final sent =
          verify(
                () => h.auth.requestOtp(
                  phone: captureAny(named: 'phone'),
                  channel: OtpChannel.whatsapp,
                ),
              ).captured.single
              as PhoneNumber;
      expect(sent.e164, '+201001234567');
      expect(find.text(l10n.adminCodeLabel), findsOneWidget);

      // Close the code step so its resend timer stops.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('after sign in', () {
    testWidgets('opens the console once the server accepts the account', (
      tester,
    ) async {
      await pumpApp(tester);

      await signIn(tester);

      expect(find.text(l10n.adminOverviewTitle), findsWidgets);
      expect(find.text(l10n.adminSignOut), findsOneWidget);
      verify(() => h.overview.fetchOverview(OverviewPeriod.today)).called(1);
    });

    testWidgets('shows the no-access screen and signs out for a non-admin', (
      tester,
    ) async {
      when(
        () => h.overview.fetchOverview(any()),
      ).thenAnswer((_) async => const Err(AdminRequiredFailure()));
      await pumpApp(tester);

      await signIn(tester);

      expect(find.text(l10n.adminNoAccessTitle), findsOneWidget);
      expect(find.text(l10n.adminOverviewTitle), findsNothing);
      verify(h.auth.signOut).called(1);
    });

    testWidgets('keeps the no-access screen through the sign out', (
      tester,
    ) async {
      when(
        () => h.overview.fetchOverview(any()),
      ).thenAnswer((_) async => const Err(AdminRequiredFailure()));
      await pumpApp(tester);
      await signIn(tester);

      users.add(null);
      await tester.pumpAndSettle();
      expect(find.text(l10n.adminNoAccessTitle), findsOneWidget);

      await tester.tap(find.text(l10n.adminNoAccessBack));
      await tester.pumpAndSettle();
      expect(find.text(l10n.adminLoginTitle), findsOneWidget);
    });

    testWidgets('says the server could not be asked, and asks again', (
      tester,
    ) async {
      when(
        () => h.overview.fetchOverview(any()),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      await pumpApp(tester);
      await signIn(tester);
      expect(find.text(l10n.adminUnavailableTitle), findsOneWidget);

      when(
        () => h.overview.fetchOverview(any()),
      ).thenAnswer((_) async => Ok(testOverview()));
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminOverviewTitle), findsWidgets);
    });

    testWidgets('goes back to the sign in after signing out', (tester) async {
      await pumpApp(tester);
      await signIn(tester);

      await tester.tap(find.text(l10n.adminSignOut));
      verify(h.auth.signOut).called(1);
      users.add(null);
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminLoginTitle), findsOneWidget);
    });
  });

  group('the menu', () {
    testWidgets('counts what waits for the team', (tester) async {
      await pumpApp(tester);

      await signIn(tester);

      Finder badge(String item, String count) => find.descendant(
        of: find.widgetWithText(InkWell, item),
        matching: find.text(count),
      );
      expect(badge(l10n.adminNavVerification, '12'), findsOneWidget);
      expect(badge(l10n.adminNavRequests, '3'), findsOneWidget);
      expect(badge(l10n.adminNavTransfers, '7'), findsOneWidget);
    });

    testWidgets('opens the page of the item tapped', (tester) async {
      when(
        () => h.audit.fetchLog(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => const Ok(PagedResult<AuditEntry>(items: [], total: 0)),
      );
      await pumpApp(tester);
      await signIn(tester);

      await tester.tap(find.text(l10n.adminNavAudit));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminAuditTitle), findsWidgets);
    });
  });

  group('adminRedirect', () {
    const checking = AdminSessionChecking();

    test('keeps every state on its own screen', () {
      expect(adminRedirect(checking, AdminRoutes.overview), '/');
      expect(adminRedirect(checking, AdminRoutes.checking), isNull);
      expect(
        adminRedirect(const AdminSessionSignedOut(), AdminRoutes.users),
        AdminRoutes.login,
      );
      expect(
        adminRedirect(const AdminSessionSignedOut(), AdminRoutes.login),
        isNull,
      );
      expect(
        adminRedirect(const AdminSessionNoAccess(), AdminRoutes.settings),
        AdminRoutes.noAccess,
      );
      expect(
        adminRedirect(
          const AdminSessionUnavailable(NetworkFailure()),
          AdminRoutes.audit,
        ),
        AdminRoutes.unavailable,
      );
    });

    test('opens a console address only for a ready admin', () {
      for (final path in AdminRoutes.console) {
        expect(adminRedirect(const AdminSessionReady(), path), isNull);
        expect(
          adminRedirect(const AdminSessionSignedOut(), path),
          AdminRoutes.login,
        );
        expect(
          adminRedirect(const AdminSessionNoAccess(), path),
          AdminRoutes.noAccess,
        );
        expect(adminRedirect(checking, path), AdminRoutes.checking);
      }
    });

    test('sends a ready admin from a gate address to the overview', () {
      for (final path in [
        AdminRoutes.checking,
        AdminRoutes.login,
        AdminRoutes.noAccess,
        AdminRoutes.unavailable,
        '/somewhere-else',
      ]) {
        expect(
          adminRedirect(const AdminSessionReady(), path),
          AdminRoutes.overview,
        );
      }
    });
  });
}
