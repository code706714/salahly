import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/pages/technician_account_page.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

SessionReady _technician([
  VerificationStatus status = VerificationStatus.approved,
]) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود السيد',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(verificationStatus: status, jobCredits: 1),
  ),
);

void main() {
  late MockSessionCubit session;
  late MockSyncCubit sync;

  setUpAll(() async {
    await loadAppFonts();
    TechnicianApp.registerFallbacks();
  });

  setUp(() {
    session = MockSessionCubit();
    sync = MockSyncCubit();
    when(() => session.state).thenReturn(_technician());
    when(session.signOut).thenAnswer((_) async {});
    when(() => sync.state).thenReturn(const SyncState());
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const TechnicianAccountPage(),
    blocs: [
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<SyncCubit>.value(value: sync),
    ],
    stubRoutes: [AppRoutes.terms, AppRoutes.privacy],
  );

  Future<void> askToSignOut(WidgetTester tester) async {
    await tester.tap(find.text(l10n.signOut));
    await tester.pumpAndSettle();
  }

  testWidgets('shows who is signed in on a small phone', (tester) async {
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.myAccount), findsOneWidget);
    expect(find.text('محمود السيد'), findsOneWidget);
    expect(find.text('+20 100 234 5678'), findsOneWidget);
    expect(find.text(l10n.accountVerified), findsOneWidget);
    expect(find.text(l10n.accountHelp), findsOneWidget);
  });

  testWidgets('tells where the ID check stands until approved', (
    tester,
  ) async {
    when(
      () => session.state,
    ).thenReturn(_technician(VerificationStatus.pending));
    await pumpPage(tester);
    expect(find.text(l10n.techPendingTitle), findsOneWidget);
    expect(find.text(l10n.accountVerified), findsNothing);

    when(
      () => session.state,
    ).thenReturn(_technician(VerificationStatus.rejected));
    await pumpPage(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(l10n.techRejectedTitle), findsOneWidget);
  });

  testWidgets('opens the terms and the privacy policy', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text(l10n.legalTermsTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.terms), findsOneWidget);

    await pumpPage(tester);
    await tester.tap(find.text(l10n.legalPrivacyTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.privacy), findsOneWidget);
  });

  group('signing out', () {
    testWidgets('signs out once confirmed', (tester) async {
      await pumpPage(tester);

      await askToSignOut(tester);
      expect(find.text(l10n.accountSignOutTitle), findsOneWidget);
      expect(find.text(l10n.accountSignOutBody), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.signOut).last);
      await tester.pumpAndSettle();

      verify(session.signOut).called(1);
      expect(find.text(l10n.accountSignOutTitle), findsNothing);
    });

    testWidgets('stays signed in when the technician changes their mind', (
      tester,
    ) async {
      await pumpPage(tester);

      await askToSignOut(tester);
      await tester.tap(find.text(l10n.accountSignOutStay));
      await tester.pumpAndSettle();

      verifyNever(session.signOut);
      expect(find.text(l10n.accountSignOutTitle), findsNothing);
    });

    testWidgets('warns that unsent changes would be lost', (tester) async {
      when(
        () => sync.state,
      ).thenReturn(const SyncState(hasNetwork: false, pendingChanges: 3));
      await pumpPage(tester);

      await askToSignOut(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.accountSignOutUnsent(3)), findsOneWidget);
      expect(find.text(l10n.accountSignOutBody), findsNothing);
    });
  });

  testWidgets('shows nothing while signing out', (tester) async {
    when(() => session.state).thenReturn(const SessionSignedOut());
    await pumpPage(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.myAccount), findsOneWidget);
    expect(find.text(l10n.signOut), findsNothing);
  });

  testTechnicianApp('opens from today and signs out from the phone', (
    tester,
    app,
  ) async {
    when(() => app.auth.signOut()).thenAnswer((_) async {});
    await app.pump(tester);

    await tester.tap(find.byTooltip(l10n.myAccount));
    await app.settle(tester);

    expect(find.byType(TechnicianAccountPage), findsOneWidget);
    expect(find.text(TechnicianApp.profile.fullName), findsOneWidget);
    expect(find.text('+20 100 234 5678'), findsOneWidget);

    await tester.tap(find.text(l10n.legalPrivacyTitle));
    await app.settle(tester);
    expect(find.text(l10n.legalPrivacyTitle), findsOneWidget);
    expect(find.byType(TechnicianAccountPage, skipOffstage: false), findsOne);
    await tester.tap(find.byTooltip(l10n.back));
    await app.settle(tester);

    await tester.tap(find.text(l10n.signOut));
    await app.settle(tester);
    await tester.tap(find.text(l10n.signOut).last);
    await app.settle(tester);

    verify(() => app.auth.signOut()).called(1);
  });
}
