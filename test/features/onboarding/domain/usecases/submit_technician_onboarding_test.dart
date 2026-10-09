import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:salahly/features/onboarding/domain/usecases/submit_technician_onboarding.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/result_matchers.dart';

const _cache = '/data/user/0/app.salahly/cache';
const _userId = '0c9d8e7f-1a2b-4c3d-8e9f-a0b1c2d3e4f5';

const _localPhotos = TechnicianDocuments(
  avatar: '$_cache/avatar.jpg',
  idFront: '$_cache/id_front.jpg',
  idBack: '$_cache/id_back.jpg',
  selfieWithId: '$_cache/selfie.jpg',
);

const _storedPhotos = TechnicianDocuments(
  avatar: '$_userId/avatar.jpg',
  idFront: '$_userId/id_front.jpg',
  idBack: '$_userId/id_back.jpg',
  selfieWithId: '$_userId/selfie.jpg',
);

TechnicianOnboarding _onboarding(TechnicianDocuments photos) =>
    TechnicianOnboarding(
      fullName: 'محمود السيد',
      shopName: 'ورشة النور',
      yearsExperience: 12,
      baseAreaId: 'nasr_city',
      baseLocation: const GeoPoint(lat: 30.0561, lng: 31.33),
      serviceRadiusKm: 10,
      workDays: const {6, 7, 1, 2, 3, 4},
      areaIds: const {'nasr_city', 'heliopolis'},
      startingPricesPiastres: const {'leak_repair': 15000},
      photos: photos,
    );

/// The storage path the fake upload returns for [localPath].
String _storedPathOf(String localPath) =>
    '$_userId/${localPath.split('/').last}';

void main() {
  late MockOnboardingRepository repository;
  late SubmitTechnicianOnboarding submit;

  void stubUpload(String localPath, Result<String> result) => when(
    () => repository.uploadPhoto(localPath, any()),
  ).thenAnswer((_) async => result);

  void stubSave(Result<void> result) => when(
    () => repository.completeTechnicianOnboarding(any()),
  ).thenAnswer((_) async => result);

  setUpAll(() {
    registerFallbackValue(PhotoKind.avatar);
    registerFallbackValue(_onboarding(_localPhotos));
  });

  setUp(() {
    repository = MockOnboardingRepository();
    submit = SubmitTechnicianOnboarding(repository);
    when(() => repository.uploadPhoto(any(), any())).thenAnswer(
      (invocation) async =>
          Ok(_storedPathOf(invocation.positionalArguments.first as String)),
    );
    stubSave(const Ok(null));
  });

  group('SubmitTechnicianOnboarding', () {
    test('uploads the four photos, then saves the profile with their '
        'storage paths', () async {
      final result = await submit(_onboarding(_localPhotos));

      expect(result, isOk());
      verifyInOrder([
        () => repository.uploadPhoto(_localPhotos.avatar, PhotoKind.avatar),
        () => repository.uploadPhoto(
          _localPhotos.idFront,
          PhotoKind.idDocument,
        ),
        () => repository.uploadPhoto(
          _localPhotos.idBack,
          PhotoKind.idDocument,
        ),
        () => repository.uploadPhoto(
          _localPhotos.selfieWithId,
          PhotoKind.idDocument,
        ),
        () => repository.completeTechnicianOnboarding(
          _onboarding(_storedPhotos),
        ),
      ]);
    });

    test('stops at a failed upload without saving the profile', () async {
      stubUpload(_localPhotos.idBack, const Err(NetworkFailure()));

      final result = await submit(_onboarding(_localPhotos));

      expect(result, isErr(const NetworkFailure()));
      verifyNever(
        () => repository.uploadPhoto(_localPhotos.selfieWithId, any()),
      );
      verifyNever(() => repository.completeTechnicianOnboarding(any()));
    });

    test('a retry uploads only the photos that are still missing', () async {
      stubUpload(_localPhotos.idBack, const Err(NetworkFailure()));
      await submit(_onboarding(_localPhotos));
      clearInteractions(repository);
      stubUpload(
        _localPhotos.idBack,
        Ok(_storedPathOf(_localPhotos.idBack)),
      );

      final result = await submit(_onboarding(_localPhotos));

      expect(result, isOk());
      verifyInOrder([
        () => repository.uploadPhoto(
          _localPhotos.idBack,
          PhotoKind.idDocument,
        ),
        () => repository.uploadPhoto(
          _localPhotos.selfieWithId,
          PhotoKind.idDocument,
        ),
        () => repository.completeTechnicianOnboarding(
          _onboarding(_storedPhotos),
        ),
      ]);
      verifyNoMoreInteractions(repository);
    });

    test('a retry uploads a photo the user took again', () async {
      stubSave(const Err(NetworkFailure()));
      await submit(_onboarding(_localPhotos));
      clearInteractions(repository);
      stubSave(const Ok(null));
      const retaken = TechnicianDocuments(
        avatar: '$_cache/avatar_retaken.jpg',
        idFront: '$_cache/id_front.jpg',
        idBack: '$_cache/id_back.jpg',
        selfieWithId: '$_cache/selfie.jpg',
      );

      await submit(_onboarding(retaken));

      verifyInOrder([
        () => repository.uploadPhoto(retaken.avatar, PhotoKind.avatar),
        () => repository.completeTechnicianOnboarding(
          _onboarding(
            const TechnicianDocuments(
              avatar: '$_userId/avatar_retaken.jpg',
              idFront: '$_userId/id_front.jpg',
              idBack: '$_userId/id_back.jpg',
              selfieWithId: '$_userId/selfie.jpg',
            ),
          ),
        ),
      ]);
      verifyNoMoreInteractions(repository);
    });

    test('treats an already saved profile as success', () async {
      stubSave(const Err(AlreadyOnboardedFailure()));

      expect(await submit(_onboarding(_localPhotos)), isOk());
    });

    test('returns a failed save and keeps the uploads for a retry', () async {
      stubSave(const Err(NetworkFailure()));

      expect(
        await submit(_onboarding(_localPhotos)),
        isErr(const NetworkFailure()),
      );

      clearInteractions(repository);
      stubSave(const Ok(null));

      expect(await submit(_onboarding(_localPhotos)), isOk());
      verifyNever(() => repository.uploadPhoto(any(), any()));
      verify(
        () => repository.completeTechnicianOnboarding(
          _onboarding(_storedPhotos),
        ),
      ).called(1);
    });

    test('uploads every photo again after the server rejects them', () async {
      stubSave(const Err(InvalidPhotosFailure()));

      expect(
        await submit(_onboarding(_localPhotos)),
        isErr(const InvalidPhotosFailure()),
      );

      clearInteractions(repository);
      stubSave(const Ok(null));

      expect(await submit(_onboarding(_localPhotos)), isOk());
      verify(() => repository.uploadPhoto(any(), any())).called(4);
    });
  });
}
