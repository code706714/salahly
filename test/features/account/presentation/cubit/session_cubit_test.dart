import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';

import '../../../../helpers/mocks.dart';

const _userId = '5b1f5c2e-6a43-4d1b-9a0e-2f7c8d9e0a11';
const _otherUserId = '0c9d8e7f-1a2b-4c3d-8e9f-a0b1c2d3e4f5';

const _user = AuthUser(id: _userId);
const _otherUser = AuthUser(id: _otherUserId);

const _cachedProfile = UserProfile(
  id: _userId,
  phone: '+201002345678',
  fullName: 'منى عبد الرحمن',
  activeRole: UserRole.consumer,
  consumer: ConsumerProfile(
    honorific: Honorific.ms,
    areaId: 'nasr_city',
    areaName: 'مدينة نصر',
    requestCredits: 2,
  ),
);

const _freshProfile = UserProfile(
  id: _userId,
  phone: '+201002345678',
  fullName: 'منى عبد الرحمن',
  activeRole: UserRole.consumer,
  consumer: ConsumerProfile(
    honorific: Honorific.ms,
    areaId: 'nasr_city',
    areaName: 'مدينة نصر',
    requestCredits: 1,
  ),
);

const _otherProfile = UserProfile(
  id: _otherUserId,
  phone: '+201112345678',
  fullName: 'محمود السيد',
  activeRole: UserRole.technician,
  technician: TechnicianProfile(
    verificationStatus: VerificationStatus.approved,
    jobCredits: 2,
  ),
);

void main() {
  late MockAuthRepository authRepository;
  late MockAccountRepository accountRepository;
  late MockUserScopedData userData;
  late StreamController<AuthUser?> userChanges;
  AuthUser? currentUser;

  void authChanged(AuthUser? user) {
    currentUser = user;
    userChanges.add(user);
  }

  SessionCubit buildCubit() => SessionCubit(
    authRepository: authRepository,
    accountRepository: accountRepository,
    userData: userData,
  );

  setUp(() {
    authRepository = MockAuthRepository();
    accountRepository = MockAccountRepository();
    userData = MockUserScopedData();
    when(() => userData.claimFor(any())).thenAnswer((_) async {});
    when(() => userData.clear()).thenAnswer((_) async {});
    userChanges = StreamController<AuthUser?>.broadcast();
    currentUser = null;
    when(
      () => authRepository.userChanges,
    ).thenAnswer((_) => userChanges.stream);
    when(() => authRepository.currentUser).thenAnswer((_) => currentUser);
    when(() => accountRepository.clearCache()).thenAnswer((_) async {});
    when(
      () => accountRepository.cachedProfile(any()),
    ).thenAnswer((_) async => null);
    when(
      () => accountRepository.fetchProfile(any()),
    ).thenAnswer((_) async => const Ok(_freshProfile));
  });

  tearDown(() => userChanges.close());

  group('SessionCubit', () {
    test('starts by loading the session', () async {
      final cubit = buildCubit();

      expect(cubit.state, const SessionLoading());
      await cubit.close();
    });

    test('stops listening to auth changes when closed', () async {
      final cubit = buildCubit();
      expect(userChanges.hasListener, isTrue);

      await cubit.close();

      expect(userChanges.hasListener, isFalse);
    });

    group('when no one is signed in', () {
      blocTest<SessionCubit, SessionState>(
        'reports signed out and clears the cached profile',
        build: buildCubit,
        act: (_) => authChanged(null),
        expect: () => [const SessionSignedOut()],
        verify: (_) {
          verify(() => accountRepository.clearCache()).called(1);
          verify(() => userData.clear()).called(1);
        },
      );

      blocTest<SessionCubit, SessionState>(
        'still reports signed out when local data cannot be deleted',
        setUp: () => when(
          () => userData.clear(),
        ).thenThrow(StateError('disk full')),
        build: buildCubit,
        act: (_) => authChanged(null),
        expect: () => [const SessionSignedOut()],
        errors: () => [isA<StateError>()],
      );

      blocTest<SessionCubit, SessionState>(
        'does not report signed out once a user signed in again',
        build: buildCubit,
        act: (_) async {
          final clearing = Completer<void>();
          when(
            () => accountRepository.clearCache(),
          ).thenAnswer((_) => clearing.future);

          authChanged(null);
          await pumpEventQueue();
          authChanged(_user);
          await pumpEventQueue();
          clearing.complete();
        },
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
        ],
      );
    });

    group('when a user is signed in', () {
      blocTest<SessionCubit, SessionState>(
        'shows the cached profile at once, then the one from the server',
        setUp: () => when(
          () => accountRepository.cachedProfile(_userId),
        ).thenAnswer((_) async => _cachedProfile),
        build: buildCubit,
        act: (cubit) async {
          final fetching = Completer<Result<UserProfile?>>();
          when(
            () => accountRepository.fetchProfile(_userId),
          ).thenAnswer((_) => fetching.future);

          authChanged(_user);
          await pumpEventQueue();
          expect(
            cubit.state,
            const SessionReady(user: _user, profile: _cachedProfile),
          );
          fetching.complete(const Ok(_freshProfile));
        },
        expect: () => [
          const SessionReady(user: _user, profile: _cachedProfile),
          const SessionReady(user: _user, profile: _freshProfile),
        ],
      );

      blocTest<SessionCubit, SessionState>(
        "makes the phone's local data this user's before showing anything",
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
        ],
        verify: (_) => verifyInOrder([
          () => userData.claimFor(_userId),
          () => accountRepository.cachedProfile(_userId),
        ]),
      );

      blocTest<SessionCubit, SessionState>(
        'still signs in when local data cannot be prepared',
        setUp: () => when(
          () => userData.claimFor(any()),
        ).thenThrow(StateError('disk full')),
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
        ],
        errors: () => [isA<StateError>()],
      );

      blocTest<SessionCubit, SessionState>(
        'shows the profile from the server when none is cached',
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
        ],
      );

      blocTest<SessionCubit, SessionState>(
        'asks for onboarding when the user has no profile yet',
        setUp: () => when(
          () => accountRepository.fetchProfile(_userId),
        ).thenAnswer((_) async => const Ok(null)),
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [const SessionNeedsOnboarding(_user)],
      );

      blocTest<SessionCubit, SessionState>(
        'reports the profile unavailable when it cannot be fetched and '
        'none is cached',
        setUp: () => when(
          () => accountRepository.fetchProfile(_userId),
        ).thenAnswer((_) async => const Err(NetworkFailure())),
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [const SessionProfileUnavailable(_user)],
      );

      blocTest<SessionCubit, SessionState>(
        'keeps showing the cached profile when it cannot be fetched',
        setUp: () {
          when(
            () => accountRepository.cachedProfile(_userId),
          ).thenAnswer((_) async => _cachedProfile);
          when(
            () => accountRepository.fetchProfile(_userId),
          ).thenAnswer((_) async => const Err(NetworkFailure()));
        },
        build: buildCubit,
        act: (_) => authChanged(_user),
        expect: () => [
          const SessionReady(user: _user, profile: _cachedProfile),
        ],
      );
    });

    group('when the user changes while loading', () {
      blocTest<SessionCubit, SessionState>(
        'ignores a profile that arrives after the user signed out',
        build: buildCubit,
        act: (_) async {
          final fetching = Completer<Result<UserProfile?>>();
          when(
            () => accountRepository.fetchProfile(_userId),
          ).thenAnswer((_) => fetching.future);

          authChanged(_user);
          await pumpEventQueue();
          authChanged(null);
          await pumpEventQueue();
          fetching.complete(const Ok(_freshProfile));
        },
        expect: () => [const SessionSignedOut()],
      );

      blocTest<SessionCubit, SessionState>(
        "ignores the previous account's cached and fetched profiles",
        build: buildCubit,
        act: (_) async {
          final readingCache = Completer<UserProfile?>();
          final fetching = Completer<Result<UserProfile?>>();
          when(
            () => accountRepository.cachedProfile(_userId),
          ).thenAnswer((_) => readingCache.future);
          when(
            () => accountRepository.fetchProfile(_userId),
          ).thenAnswer((_) => fetching.future);
          when(
            () => accountRepository.fetchProfile(_otherUserId),
          ).thenAnswer((_) async => const Ok(_otherProfile));

          authChanged(_user);
          await pumpEventQueue();
          authChanged(_otherUser);
          await pumpEventQueue();
          readingCache.complete(_cachedProfile);
          await pumpEventQueue();
          fetching.complete(const Ok(_freshProfile));
        },
        expect: () => [
          const SessionReady(user: _otherUser, profile: _otherProfile),
        ],
      );

      blocTest<SessionCubit, SessionState>(
        "never keeps the previous account's profile when the new one fails",
        build: buildCubit,
        act: (_) async {
          when(
            () => accountRepository.fetchProfile(_otherUserId),
          ).thenAnswer((_) async => const Err(NetworkFailure()));

          authChanged(_user);
          await pumpEventQueue();
          authChanged(_otherUser);
          await pumpEventQueue();
        },
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
          const SessionProfileUnavailable(_otherUser),
        ],
      );

      test('ignores a profile that arrives after the cubit closed', () async {
        final fetching = Completer<Result<UserProfile?>>();
        when(
          () => accountRepository.fetchProfile(_userId),
        ).thenAnswer((_) => fetching.future);
        final cubit = buildCubit();

        authChanged(_user);
        await pumpEventQueue();
        await cubit.close();
        fetching.complete(const Ok(_freshProfile));
        await pumpEventQueue();

        expect(cubit.state, const SessionLoading());
      });
    });

    group('refreshProfile', () {
      blocTest<SessionCubit, SessionState>(
        "fetches the signed-in user's profile again",
        setUp: () => currentUser = _user,
        build: buildCubit,
        seed: () => const SessionProfileUnavailable(_user),
        act: (cubit) => cubit.refreshProfile(),
        expect: () => [
          const SessionReady(user: _user, profile: _freshProfile),
        ],
      );

      blocTest<SessionCubit, SessionState>(
        'does nothing when no one is signed in',
        build: buildCubit,
        act: (cubit) => cubit.refreshProfile(),
        expect: () => <SessionState>[],
        verify: (_) => verifyNever(() => accountRepository.fetchProfile(any())),
      );
    });

    group('signOut', () {
      blocTest<SessionCubit, SessionState>(
        'signs out and forgets the cached profile',
        setUp: () {
          currentUser = _user;
          when(
            () => authRepository.signOut(),
          ).thenAnswer((_) async => authChanged(null));
        },
        build: buildCubit,
        seed: () => const SessionReady(user: _user, profile: _cachedProfile),
        act: (cubit) => cubit.signOut(),
        expect: () => [const SessionSignedOut()],
        verify: (_) {
          verify(() => authRepository.signOut()).called(1);
          verify(() => accountRepository.clearCache()).called(1);
        },
      );
    });

    group('signOutAndReturnTo', () {
      test('brings the same user back once they sign in again', () async {
        currentUser = _user;
        when(
          () => authRepository.signOut(),
        ).thenAnswer((_) async => authChanged(null));
        final cubit = buildCubit();

        await cubit.signOutAndReturnTo('/consumer/account/delete');

        expect(cubit.takeReturnTo(_user), '/consumer/account/delete');
        expect(cubit.takeReturnTo(_user), isNull);
        await cubit.close();
      });

      test('does not send somebody else there', () async {
        currentUser = _user;
        when(
          () => authRepository.signOut(),
        ).thenAnswer((_) async => authChanged(null));
        final cubit = buildCubit();

        await cubit.signOutAndReturnTo('/consumer/account/delete');

        expect(cubit.takeReturnTo(_otherUser), isNull);
        expect(cubit.takeReturnTo(_user), isNull);
        await cubit.close();
      });

      test('forgets the place when signing out failed', () async {
        currentUser = _user;
        when(() => authRepository.signOut()).thenThrow(StateError('offline'));
        final cubit = buildCubit();

        await expectLater(
          cubit.signOutAndReturnTo('/consumer/account/delete'),
          throwsStateError,
        );

        expect(cubit.takeReturnTo(_user), isNull);
        await cubit.close();
      });
    });

    group('signOutDeleted', () {
      blocTest<SessionCubit, SessionState>(
        'erases the data on the phone even when signing out fails',
        setUp: () {
          currentUser = _user;
          when(() => authRepository.signOut()).thenThrow(StateError('offline'));
        },
        build: buildCubit,
        seed: () => const SessionReady(user: _user, profile: _cachedProfile),
        act: (cubit) => cubit.signOutDeleted(),
        errors: () => [isA<StateError>()],
        verify: (_) {
          verify(() => accountRepository.clearCache()).called(1);
          verify(() => userData.clear()).called(1);
        },
      );
    });
  });
}
