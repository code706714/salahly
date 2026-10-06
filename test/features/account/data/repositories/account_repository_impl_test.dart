import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/account/data/datasources/account_local_data_source.dart';
import 'package:salahly/features/account/data/datasources/account_remote_data_source.dart';
import 'package:salahly/features/account/data/repositories/account_repository_impl.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/result_matchers.dart';

class MockAccountRemoteDataSource extends Mock
    implements AccountRemoteDataSource {}

class MockAccountLocalDataSource extends Mock
    implements AccountLocalDataSource {}

const _userId = '5b1f5c2e-6a43-4d1b-9a0e-2f7c8d9e0a11';

Map<String, dynamic> _row() => {
  'id': _userId,
  'phone': '+201002345678',
  'full_name': 'منى عبد الرحمن',
  'active_role': 'consumer',
  'consumer_profiles': {
    'honorific': 'ms',
    'request_credits': 2,
    'area_id': 'nasr_city',
    'service_areas': {'name_ar': 'مدينة نصر'},
  },
  'technician_profiles': null,
};

const _profile = UserProfile(
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

void main() {
  late MockAccountRemoteDataSource remote;
  late MockAccountLocalDataSource local;
  late AccountRepositoryImpl repository;

  setUp(() {
    remote = MockAccountRemoteDataSource();
    local = MockAccountLocalDataSource();
    repository = AccountRepositoryImpl(remote: remote, local: local);
    when(() => local.read()).thenAnswer((_) async => null);
    when(() => local.write(any())).thenAnswer((_) async {});
    when(() => local.clear()).thenAnswer((_) async {});
  });

  group('AccountRepositoryImpl', () {
    group('cachedProfile', () {
      test('returns the profile cached for the user', () async {
        when(() => local.read()).thenAnswer((_) async => _row());

        expect(await repository.cachedProfile(_userId), _profile);
      });

      test('returns null when nothing is cached', () async {
        expect(await repository.cachedProfile(_userId), isNull);
      });

      test('returns null when the cache belongs to another account', () async {
        when(() => local.read()).thenAnswer((_) async => _row());

        expect(
          await repository.cachedProfile(
            '0c9d8e7f-1a2b-4c3d-8e9f-a0b1c2d3e4f5',
          ),
          isNull,
        );
      });

      test('discards a cache it cannot read', () async {
        when(
          () => local.read(),
        ).thenAnswer((_) => Future.error(const FormatException()));

        expect(await repository.cachedProfile(_userId), isNull);
        verify(() => local.clear()).called(1);
      });

      test('discards a cache saved in an outdated shape', () async {
        when(
          () => local.read(),
        ).thenAnswer((_) async => {..._row(), 'active_role': 'customer'});

        expect(await repository.cachedProfile(_userId), isNull);
        verify(() => local.clear()).called(1);
      });
    });

    group('deleteAccount', () {
      test('deletes on the server', () async {
        when(() => remote.deleteAccount()).thenAnswer((_) async {});

        expect(await repository.deleteAccount(), isOk());
        verify(() => remote.deleteAccount()).called(1);
      });

      test('says a transfer is still waiting', () async {
        when(() => remote.deleteAccount()).thenAnswer(
          (_) =>
              Future.error(const PostgrestException(message: 'topup_pending')),
        );

        expect(
          await repository.deleteAccount(),
          isErr(const PendingTransferFailure()),
        );
      });

      test('fails with a network failure offline', () async {
        when(
          () => remote.deleteAccount(),
        ).thenAnswer((_) => Future.error(ClientException('offline')));

        expect(await repository.deleteAccount(), isErr(const NetworkFailure()));
      });

      test('fails with an unexpected failure for anything else', () async {
        when(
          () => remote.deleteAccount(),
        ).thenAnswer(
          (_) => Future.error(const PostgrestException(message: 'x')),
        );

        expect(
          await repository.deleteAccount(),
          isErr(isA<UnexpectedFailure>()),
        );
      });
    });

    group('fetchProfile', () {
      test('returns the profile and caches its row', () async {
        when(
          () => remote.fetchProfile(_userId),
        ).thenAnswer((_) async => _row());

        expect(await repository.fetchProfile(_userId), isOk(_profile));
        verify(() => local.write(_row())).called(1);
      });

      test('returns null and clears the cache before onboarding', () async {
        when(() => remote.fetchProfile(_userId)).thenAnswer((_) async => null);

        expect(await repository.fetchProfile(_userId), isOk(isNull));
        verify(() => local.clear()).called(1);
      });

      test(
        'reports a network failure and keeps the cached profile',
        () async {
          when(() => local.read()).thenAnswer((_) async => _row());
          when(
            () => remote.fetchProfile(_userId),
          ).thenAnswer(
            (_) => Future.error(ClientException('Failed host lookup')),
          );

          expect(
            await repository.fetchProfile(_userId),
            isErr(const NetworkFailure()),
          );
          verifyNever(() => local.write(any()));
          verifyNever(() => local.clear());
          expect(await repository.cachedProfile(_userId), _profile);
        },
      );

      test('returns the profile even when caching it fails', () async {
        when(
          () => remote.fetchProfile(_userId),
        ).thenAnswer((_) async => _row());
        when(
          () => local.write(any()),
        ).thenAnswer((_) => Future.error(Exception('keystore')));

        expect(await repository.fetchProfile(_userId), isOk(_profile));
      });

      test('returns null even when clearing the cache fails', () async {
        when(() => remote.fetchProfile(_userId)).thenAnswer((_) async => null);
        when(
          () => local.clear(),
        ).thenAnswer((_) => Future.error(Exception('keystore')));

        expect(await repository.fetchProfile(_userId), isOk(isNull));
      });

      test('does not cache a row it cannot read', () async {
        when(
          () => remote.fetchProfile(_userId),
        ).thenAnswer((_) async => {..._row(), 'full_name': null});

        expect(
          await repository.fetchProfile(_userId),
          isErr(isA<UnexpectedFailure>()),
        );
        verifyNever(() => local.write(any()));
      });
    });

    test('clearCache clears the device cache', () async {
      await repository.clearCache();

      verify(() => local.clear()).called(1);
    });

    test('clearCache completes when the device storage fails', () async {
      when(
        () => local.clear(),
      ).thenAnswer((_) => Future.error(Exception('keystore')));

      await expectLater(repository.clearCache(), completes);
    });
  });
}
