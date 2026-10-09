import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/cubit/admin_session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository auth;
  late MockOverviewRepository overview;
  late StreamController<AuthUser?> users;
  const admin = AuthUser(id: 'admin-1', phone: '+201001234567');

  setUpAll(AdminHarness.registerFallbacks);

  setUp(() {
    auth = MockAuthRepository();
    overview = MockOverviewRepository();
    users = StreamController<AuthUser?>.broadcast();
    addTearDown(users.close);
    when(() => auth.userChanges).thenAnswer((_) => users.stream);
    when(auth.signOut).thenAnswer((_) async => users.add(null));
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => Ok(testOverview()));
  });

  AdminSessionCubit build() {
    final cubit = AdminSessionCubit(
      authRepository: auth,
      overviewRepository: overview,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> signIn([AuthUser user = admin]) async {
    users.add(user);
    await pumpEventQueue();
  }

  test('waits for the saved session before it says anything', () {
    expect(build().state, const AdminSessionChecking());
  });

  test('shows the sign in when nobody is signed in', () async {
    final cubit = build();

    users.add(null);
    await pumpEventQueue();

    expect(cubit.state, const AdminSessionSignedOut());
    verifyNever(() => overview.fetchOverview(any()));
  });

  test('lets an admin in once the server accepted them', () async {
    final cubit = build();

    await signIn();

    expect(cubit.state, const AdminSessionReady());
    verify(() => overview.fetchOverview(OverviewPeriod.today)).called(1);
  });

  test(
    'turns away someone the server does not accept, and signs out',
    () async {
      when(
        () => overview.fetchOverview(any()),
      ).thenAnswer((_) async => const Err(AdminRequiredFailure()));
      final cubit = build();

      await signIn();

      expect(cubit.state, const AdminSessionNoAccess());
      verify(auth.signOut).called(1);
    },
  );

  test('keeps saying so after the sign out that comes with it', () async {
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(AdminRequiredFailure()));
    final cubit = build();

    await signIn();
    await pumpEventQueue();

    expect(cubit.state, const AdminSessionNoAccess());
  });

  test('goes from the no access screen back to the sign in', () async {
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(AdminRequiredFailure()));
    final cubit = build();
    await signIn();

    cubit.leaveNoAccess();

    expect(cubit.state, const AdminSessionSignedOut());
  });

  test('leaving no access does nothing elsewhere', () async {
    final cubit = build();
    await signIn();

    cubit.leaveNoAccess();

    expect(cubit.state, const AdminSessionReady());
  });

  test('says when the server could not be asked, and asks again', () async {
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = build();
    await signIn();
    expect(cubit.state, const AdminSessionUnavailable(NetworkFailure()));
    verifyNever(auth.signOut);

    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => Ok(testOverview()));
    await cubit.retry();

    expect(cubit.state, const AdminSessionReady());
  });

  test('does not ask again when the same admin signs in anew', () async {
    final cubit = build();
    await signIn();

    await signIn();

    expect(cubit.state, const AdminSessionReady());
    verify(() => overview.fetchOverview(any())).called(1);
  });

  test('checks another person who signs in on top of the admin', () async {
    final cubit = build();
    await signIn();
    when(
      () => overview.fetchOverview(any()),
    ).thenAnswer((_) async => const Err(AdminRequiredFailure()));

    await signIn(const AuthUser(id: 'someone-else'));

    expect(cubit.state, const AdminSessionNoAccess());
  });

  test('closes the console when the admin signs out', () async {
    final cubit = build();
    await signIn();

    await cubit.signOut();
    await pumpEventQueue();

    expect(cubit.state, const AdminSessionSignedOut());
  });

  test('forgets an answer that arrives after the sign out', () async {
    final slow = Completer<Result<AdminOverview>>();
    when(() => overview.fetchOverview(any())).thenAnswer((_) => slow.future);
    final cubit = build();

    await signIn();
    users.add(null);
    await pumpEventQueue();
    slow.complete(Ok(testOverview()));
    await pumpEventQueue();

    expect(cubit.state, const AdminSessionSignedOut());
  });
}
