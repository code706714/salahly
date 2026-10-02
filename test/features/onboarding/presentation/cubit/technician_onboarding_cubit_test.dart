import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/onboarding/domain/entities/free_allowance.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:salahly/features/onboarding/domain/usecases/submit_technician_onboarding.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';

class _MockCatalogRepository extends Mock implements CatalogRepository {}

class _MockOnboardingRepository extends Mock implements OnboardingRepository {}

class _MockLocationService extends Mock implements LocationService {}

class _MockSubmitTechnicianOnboarding extends Mock
    implements SubmitTechnicianOnboarding {}

const cleaning = CatalogService(
  id: 'ac-cleaning',
  name: 'تنظيف تكييف',
  suggestedPricePiastres: 35000,
);
const installation = CatalogService(
  id: 'ac-installation',
  name: 'تركيب تكييف',
  suggestedPricePiastres: 80050,
);
const airConditioning = ServiceCategory(
  id: 'ac',
  name: 'تكييف',
  isActive: true,
  services: [cleaning, installation],
);
const nasrCity = ServiceArea(
  id: 'nasr-city',
  name: 'مدينة نصر',
  city: 'القاهرة',
  center: GeoPoint(lat: 30.0561, lng: 31.3301),
);
const maadi = ServiceArea(
  id: 'maadi',
  name: 'المعادي',
  city: 'القاهرة',
  center: GeoPoint(lat: 29.9602, lng: 31.2569),
);
const nearNasrCity = GeoPoint(lat: 30.06, lng: 31.34);
const alexandria = GeoPoint(lat: 31.2001, lng: 29.9187);

const ready = TechnicianOnboardingState(
  loadStatus: LoadStatus.ready,
  categories: [airConditioning],
  areas: [nasrCity, maadi],
  freeJobs: 3,
);
final TechnicianOnboardingState profileDone = ready.copyWith(
  avatarPath: 'avatar.jpg',
  fullName: '  محمد   السيد ',
  shopName: ' تكييفات   السيد',
  yearsText: '١٢',
);
final TechnicianOnboardingState servicesDone = profileDone.copyWith(
  step: TechnicianStep.services,
  selectedServiceIds: {cleaning.id},
  priceTexts: {cleaning.id: '٣٥٠', installation.id: '800'},
);
final TechnicianOnboardingState locationDone = servicesDone.copyWith(
  step: TechnicianStep.location,
  baseArea: nasrCity,
  baseLocation: nasrCity.center,
  radiusKm: 15,
  areaIds: {nasrCity.id, maadi.id},
);
final TechnicianOnboardingState documentsDone = locationDone.copyWith(
  step: TechnicianStep.documents,
  documents: const {
    DocumentSlot.idFront: 'id-front.jpg',
    DocumentSlot.idBack: 'id-back.jpg',
    DocumentSlot.selfieWithId: 'selfie.jpg',
  },
);

/// What [documentsDone] should submit.
final submission = TechnicianOnboarding(
  fullName: 'محمد السيد',
  shopName: 'تكييفات السيد',
  yearsExperience: 12,
  baseAreaId: nasrCity.id,
  baseLocation: nasrCity.center,
  serviceRadiusKm: 15,
  workDays: const {6, 7, 1, 2, 3, 4},
  areaIds: {nasrCity.id, maadi.id},
  startingPricesPiastres: {cleaning.id: 35000},
  photos: const TechnicianDocuments(
    avatar: 'avatar.jpg',
    idFront: 'id-front.jpg',
    idBack: 'id-back.jpg',
    selfieWithId: 'selfie.jpg',
  ),
);

void main() {
  late CatalogRepository catalogRepository;
  late OnboardingRepository onboardingRepository;
  late LocationService locationService;
  late SubmitTechnicianOnboarding submit;

  setUpAll(() => registerFallbackValue(submission));

  setUp(() {
    catalogRepository = _MockCatalogRepository();
    onboardingRepository = _MockOnboardingRepository();
    locationService = _MockLocationService();
    submit = _MockSubmitTechnicianOnboarding();

    when(
      () => catalogRepository.fetchCategories(),
    ).thenAnswer((_) async => const Ok([airConditioning]));
    when(
      () => catalogRepository.fetchAreas(),
    ).thenAnswer((_) async => const Ok([nasrCity, maadi]));
    when(() => onboardingRepository.fetchFreeAllowance()).thenAnswer(
      (_) async => const Ok(
        FreeAllowance(consumerRequests: 2, technicianJobs: 3),
      ),
    );
    when(
      () => locationService.approximatePosition(),
    ).thenAnswer((_) async => const Ok(nearNasrCity));
    when(() => submit(any())).thenAnswer((_) async => const Ok(null));
  });

  TechnicianOnboardingCubit buildCubit() => TechnicianOnboardingCubit(
    catalogRepository: catalogRepository,
    onboardingRepository: onboardingRepository,
    locationService: locationService,
    submitOnboarding: submit,
  );

  group('TechnicianOnboardingCubit', () {
    test('starts loading on the profile step', () {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      expect(cubit.state, const TechnicianOnboardingState());
    });

    group('load', () {
      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'is ready with the catalog, areas and free jobs',
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [const TechnicianOnboardingState(), ready],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'fails with the categories failure',
        setUp: () => when(
          () => catalogRepository.fetchCategories(),
        ).thenAnswer((_) async => const Err(NetworkFailure())),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const TechnicianOnboardingState(),
          const TechnicianOnboardingState(
            loadStatus: LoadStatus.failed,
            failure: NetworkFailure(),
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'fails with the areas failure',
        setUp: () => when(
          () => catalogRepository.fetchAreas(),
        ).thenAnswer((_) async => const Err(RateLimitedFailure())),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          const TechnicianOnboardingState(
            loadStatus: LoadStatus.failed,
            failure: RateLimitedFailure(),
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'fails with the free allowance failure',
        setUp: () => when(
          () => onboardingRepository.fetchFreeAllowance(),
        ).thenAnswer((_) async => const Err(UnexpectedFailure('boom'))),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        skip: 1,
        expect: () => [
          const TechnicianOnboardingState(
            loadStatus: LoadStatus.failed,
            failure: UnexpectedFailure('boom'),
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'clears the previous failure when retrying',
        build: buildCubit,
        seed: () => const TechnicianOnboardingState(
          loadStatus: LoadStatus.failed,
          failure: NetworkFailure(),
        ),
        act: (cubit) => cubit.load(),
        expect: () => [const TechnicianOnboardingState(), ready],
      );
    });

    group('profile step', () {
      test('needs a photo', () {
        final noPhoto = ready.copyWith(fullName: 'محمد', yearsText: '5');

        expect(noPhoto.isProfileValid, isFalse);
        expect(noPhoto.copyWith(avatarPath: 'a.jpg').isProfileValid, isTrue);
      });

      test('needs a name of 2 to 60 letters, ignoring extra spaces', () {
        TechnicianOnboardingState named(String name) =>
            profileDone.copyWith(fullName: name);

        expect(named(' م ').isNameValid, isFalse);
        expect(named('مح').isNameValid, isTrue);
        expect(named('م' * 60).isNameValid, isTrue);
        expect(named('م' * 61).isNameValid, isFalse);
        expect(named(' م ').isProfileValid, isFalse);
      });

      test('reads years in Arabic or Western digits, from 0 to 60', () {
        int? years(String text) =>
            ready.copyWith(yearsText: text).yearsExperience;

        expect(years('١٢'), 12);
        expect(years('0'), 0);
        expect(years('60'), 60);
        expect(years('61'), isNull);
        expect(years(''), isNull);
        expect(years('1.5'), isNull);
        expect(
          profileDone.copyWith(yearsText: '61').isProfileValid,
          isFalse,
        );
      });

      test('treats the shop name as optional but checks it when given', () {
        TechnicianOnboardingState shop(String name) =>
            profileDone.copyWith(shopName: name);

        expect(shop('').isShopNameValid, isTrue);
        expect(shop('   ').isShopNameValid, isTrue);
        expect(shop('م').isShopNameValid, isFalse);
        expect(shop('م').isProfileValid, isFalse);
        expect(shop('تكييفات السيد').isShopNameValid, isTrue);
      });

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next shows the errors and stays while the profile is incomplete',
        build: buildCubit,
        seed: () => ready.copyWith(fullName: 'محمد', yearsText: '5'),
        act: (cubit) => cubit.next(),
        expect: () => [
          ready.copyWith(fullName: 'محمد', yearsText: '5', showErrors: true),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next moves to services once photo, name and years are filled',
        build: buildCubit,
        seed: () => ready.copyWith(showErrors: true),
        act: (cubit) async {
          cubit
            ..avatarPicked('avatar.jpg')
            ..nameChanged('محمد')
            ..shopNameChanged('تكييفات السيد')
            ..yearsChanged('7');
          await cubit.next();
        },
        skip: 4,
        expect: () => [
          ready.copyWith(
            step: TechnicianStep.services,
            avatarPath: 'avatar.jpg',
            fullName: 'محمد',
            shopName: 'تكييفات السيد',
            yearsText: '7',
          ),
        ],
      );
    });

    group('services step', () {
      final onServices = ready.copyWith(step: TechnicianStep.services);

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'checking a service fills in its suggested price in pounds',
        build: buildCubit,
        seed: () => onServices,
        act: (cubit) => cubit.serviceToggled(installation),
        expect: () => [
          onServices.copyWith(
            selectedServiceIds: {installation.id},
            priceTexts: {installation.id: '800'},
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'unchecking keeps the edited price for when it is checked again',
        build: buildCubit,
        seed: () => onServices,
        act: (cubit) => cubit
          ..serviceToggled(cleaning)
          ..priceChanged(cleaning.id, '400')
          ..serviceToggled(cleaning)
          ..serviceToggled(cleaning),
        expect: () => [
          onServices.copyWith(
            selectedServiceIds: {cleaning.id},
            priceTexts: {cleaning.id: '350'},
          ),
          onServices.copyWith(
            selectedServiceIds: {cleaning.id},
            priceTexts: {cleaning.id: '400'},
          ),
          onServices.copyWith(priceTexts: {cleaning.id: '400'}),
          onServices.copyWith(
            selectedServiceIds: {cleaning.id},
            priceTexts: {cleaning.id: '400'},
          ),
        ],
      );

      test('reads prices in Arabic or Western digits as piastres', () {
        int? piastres(String text) => onServices
            .copyWith(priceTexts: {cleaning.id: text})
            .pricePiastres(cleaning.id);

        expect(piastres('٣٥٠'), 35000);
        expect(piastres('1'), 100);
        expect(piastres('1000000'), 100000000);
        expect(piastres('0'), isNull);
        expect(piastres('1000001'), isNull);
        expect(piastres(''), isNull);
        expect(piastres('150.5'), isNull);
        expect(piastres('١٥٠٫٥'), isNull);
        expect(onServices.pricePiastres(cleaning.id), isNull);
      });

      test('needs a service checked and a valid price for each one', () {
        final checked = onServices.copyWith(selectedServiceIds: {cleaning.id});

        expect(onServices.isServicesValid, isFalse);
        expect(checked.isServicesValid, isFalse);
        expect(
          checked.copyWith(priceTexts: {cleaning.id: '0'}).isServicesValid,
          isFalse,
        );
        expect(
          checked
              .copyWith(
                priceTexts: {cleaning.id: '350', installation.id: ''},
              )
              .isServicesValid,
          isTrue,
        );
      });

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next shows the errors while no service is checked',
        build: buildCubit,
        seed: () => onServices,
        act: (cubit) => cubit.next(),
        expect: () => [onServices.copyWith(showErrors: true)],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next moves to the location step and locates the technician',
        build: buildCubit,
        seed: () => servicesDone,
        act: (cubit) => cubit.next(),
        expect: () => [
          servicesDone.copyWith(step: TechnicianStep.location),
          servicesDone.copyWith(
            step: TechnicianStep.location,
            isLocating: true,
          ),
          servicesDone.copyWith(
            step: TechnicianStep.location,
            baseArea: nasrCity,
            baseLocation: nearNasrCity,
            baseSource: AreaSource.location,
            areaIds: {nasrCity.id},
          ),
        ],
        verify: (_) =>
            verify(() => locationService.approximatePosition()).called(1),
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next keeps a base chosen earlier instead of locating again',
        build: buildCubit,
        seed: () => servicesDone.copyWith(
          baseArea: maadi,
          baseLocation: maadi.center,
        ),
        act: (cubit) => cubit.next(),
        expect: () => [
          servicesDone.copyWith(
            step: TechnicianStep.location,
            baseArea: maadi,
            baseLocation: maadi.center,
          ),
        ],
        verify: (_) => verifyNever(() => locationService.approximatePosition()),
      );
    });

    group('location step', () {
      final onLocation = servicesDone.copyWith(step: TechnicianStep.location);

      test('offers 5, 10 and 15 km and defaults to 10 km', () {
        expect(TechnicianOnboardingState.radiusOptions, [5, 10, 15]);
        expect(const TechnicianOnboardingState().radiusKm, 10);
      });

      test('defaults the work days to Saturday through Thursday', () {
        expect(const TechnicianOnboardingState().workDays, {
          DateTime.saturday,
          DateTime.sunday,
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
        });
      });

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'changes the radius',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit
          ..radiusChanged(5)
          ..radiusChanged(15),
        expect: () => [
          onLocation.copyWith(radiusKm: 5),
          onLocation.copyWith(radiusKm: 15),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'toggles work days on and off',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit
          ..workDayToggled(DateTime.friday)
          ..workDayToggled(DateTime.saturday),
        expect: () => [
          onLocation.copyWith(workDays: {6, 7, 1, 2, 3, 4, 5}),
          onLocation.copyWith(workDays: {7, 1, 2, 3, 4, 5}),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'toggles service areas on and off',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit
          ..areaToggled(maadi.id)
          ..areaToggled(nasrCity.id)
          ..areaToggled(maadi.id),
        expect: () => [
          onLocation.copyWith(areaIds: {maadi.id}),
          onLocation.copyWith(areaIds: {maadi.id, nasrCity.id}),
          onLocation.copyWith(areaIds: {nasrCity.id}),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'a base picked by hand sits at the area center and is preselected',
        build: buildCubit,
        seed: () => onLocation.copyWith(
          locationFailure: () => const LocationDisabledFailure(),
        ),
        act: (cubit) => cubit.basePicked(maadi),
        expect: () => [
          onLocation.copyWith(
            baseArea: maadi,
            baseLocation: maadi.center,
            areaIds: {maadi.id},
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'a new base keeps the areas already chosen',
        build: buildCubit,
        seed: () => onLocation.copyWith(areaIds: {nasrCity.id}),
        act: (cubit) => cubit.basePicked(maadi),
        expect: () => [
          onLocation.copyWith(
            baseArea: maadi,
            baseLocation: maadi.center,
            areaIds: {nasrCity.id},
          ),
        ],
      );

      test('needs a base, an area and a work day', () {
        expect(locationDone.isLocationValid, isTrue);
        expect(onLocation.isLocationValid, isFalse);
        expect(locationDone.copyWith(areaIds: {}).isLocationValid, isFalse);
        expect(locationDone.copyWith(workDays: {}).isLocationValid, isFalse);
      });

      group('suggested areas', () {
        final areas = [
          for (var i = 0; i < 8; i++)
            ServiceArea(
              id: 'area-$i',
              name: 'منطقة $i',
              city: 'القاهرة',
              center: GeoPoint(lat: 30 + i * 0.01, lng: 31),
            ),
        ];
        final withAreas = ready.copyWith(areas: areas);
        const nearLastArea = GeoPoint(lat: 30.1, lng: 31);

        List<String> suggestedIds(TechnicianOnboardingState state) =>
            state.suggestedAreas.map((area) => area.id).toList();

        test('are the first six areas, then the chosen ones after them', () {
          expect(suggestedIds(withAreas.copyWith(areaIds: {'area-7'})), [
            'area-0',
            'area-1',
            'area-2',
            'area-3',
            'area-4',
            'area-5',
            'area-7',
          ]);
        });

        test('are the six closest to the base, then the chosen ones', () {
          final located = withAreas.copyWith(baseLocation: nearLastArea);

          expect(suggestedIds(located.copyWith(areaIds: {'area-0'})), [
            'area-7',
            'area-6',
            'area-5',
            'area-4',
            'area-3',
            'area-2',
            'area-0',
          ]);
          expect(
            suggestedIds(located.copyWith(areaIds: {'area-7'})),
            ['area-7', 'area-6', 'area-5', 'area-4', 'area-3', 'area-2'],
          );
        });
      });

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next shows the errors while the location is incomplete',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit.next(),
        expect: () => [onLocation.copyWith(showErrors: true)],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next moves to the documents step once the location is complete',
        build: buildCubit,
        seed: () => locationDone.copyWith(showErrors: true),
        act: (cubit) => cubit.next(),
        expect: () => [
          locationDone.copyWith(step: TechnicianStep.documents),
        ],
      );
    });

    group('locate', () {
      final onLocation = servicesDone.copyWith(step: TechnicianStep.location);

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'sets the base to the area around the device',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit.locate(),
        expect: () => [
          onLocation.copyWith(isLocating: true),
          onLocation.copyWith(
            baseArea: nasrCity,
            baseLocation: nearNasrCity,
            baseSource: AreaSource.location,
            areaIds: {nasrCity.id},
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'leaves the base empty when no area is near the device',
        setUp: () => when(
          () => locationService.approximatePosition(),
        ).thenAnswer((_) async => const Ok(alexandria)),
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) => cubit.locate(),
        expect: () => [onLocation.copyWith(isLocating: true), onLocation],
      );

      for (final (reason, failure) in const <(String, Failure)>[
        ('a refused permission', LocationPermissionFailure(permanently: true)),
        ('location services being off', LocationDisabledFailure()),
      ]) {
        blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
          'reports $reason',
          setUp: () => when(
            () => locationService.approximatePosition(),
          ).thenAnswer((_) async => Err(failure)),
          build: buildCubit,
          seed: () => onLocation,
          act: (cubit) => cubit.locate(),
          expect: () => [
            onLocation.copyWith(isLocating: true),
            onLocation.copyWith(locationFailure: () => failure),
          ],
        );
      }

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'clears the previous failure when trying again',
        build: buildCubit,
        seed: () => onLocation.copyWith(
          locationFailure: () => const LocationDisabledFailure(),
        ),
        act: (cubit) => cubit.locate(),
        expect: () => [
          onLocation.copyWith(isLocating: true),
          onLocation.copyWith(
            baseArea: nasrCity,
            baseLocation: nearNasrCity,
            baseSource: AreaSource.location,
            areaIds: {nasrCity.id},
          ),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'emits nothing once closed before the position arrives',
        build: buildCubit,
        seed: () => onLocation,
        act: (cubit) async {
          final position = Completer<Result<GeoPoint>>();
          when(
            () => locationService.approximatePosition(),
          ).thenAnswer((_) => position.future);

          final locating = cubit.locate();
          await cubit.close();
          position.complete(const Ok(nearNasrCity));
          await locating;
        },
        expect: () => [onLocation.copyWith(isLocating: true)],
      );
    });

    group('documents step', () {
      final onDocuments = locationDone.copyWith(step: TechnicianStep.documents);

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'stores each picked photo in its slot',
        build: buildCubit,
        seed: () => onDocuments,
        act: (cubit) => cubit
          ..documentPicked(DocumentSlot.idFront, 'front.jpg')
          ..documentPicked(DocumentSlot.idFront, 'front-retake.jpg')
          ..documentPicked(DocumentSlot.selfieWithId, 'selfie.jpg'),
        expect: () => [
          onDocuments.copyWith(
            documents: {DocumentSlot.idFront: 'front.jpg'},
          ),
          onDocuments.copyWith(
            documents: {DocumentSlot.idFront: 'front-retake.jpg'},
          ),
          onDocuments.copyWith(
            documents: {
              DocumentSlot.idFront: 'front-retake.jpg',
              DocumentSlot.selfieWithId: 'selfie.jpg',
            },
          ),
        ],
      );

      test('needs the front, the back and the selfie', () {
        expect(onDocuments.isDocumentsValid, isFalse);
        expect(
          onDocuments
              .copyWith(
                documents: {
                  DocumentSlot.idFront: 'front.jpg',
                  DocumentSlot.idBack: 'back.jpg',
                },
              )
              .isDocumentsValid,
          isFalse,
        );
        expect(documentsDone.isDocumentsValid, isTrue);
      });

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'next shows the errors and submits nothing while a photo is missing',
        build: buildCubit,
        seed: () => onDocuments,
        act: (cubit) => cubit.next(),
        expect: () => [onDocuments.copyWith(showErrors: true)],
        verify: (_) => verifyNever(() => submit(any())),
      );
    });

    group('back', () {
      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'returns false on the first step so the page can leave',
        build: buildCubit,
        seed: () => profileDone,
        act: (cubit) => expect(cubit.back(), isFalse),
        expect: () => <TechnicianOnboardingState>[],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'goes to the previous step without the errors or failure',
        build: buildCubit,
        seed: () => documentsDone.copyWith(
          showErrors: true,
          failure: () => const NetworkFailure(),
        ),
        act: (cubit) => expect(cubit.back(), isTrue),
        expect: () => [
          documentsDone.copyWith(step: TechnicianStep.location),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'stays on the done step',
        build: buildCubit,
        seed: () => documentsDone.copyWith(step: TechnicianStep.done),
        act: (cubit) => expect(cubit.back(), isTrue),
        expect: () => <TechnicianOnboardingState>[],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'stays put while submitting',
        build: buildCubit,
        seed: () => documentsDone.copyWith(isSubmitting: true),
        act: (cubit) => expect(cubit.back(), isTrue),
        expect: () => <TechnicianOnboardingState>[],
      );
    });

    group('submit', () {
      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'sends the cleaned-up form and finishes on success',
        build: buildCubit,
        seed: () => documentsDone,
        act: (cubit) => cubit.next(),
        expect: () => [
          documentsDone.copyWith(isSubmitting: true),
          documentsDone.copyWith(step: TechnicianStep.done),
        ],
        verify: (_) => verify(() => submit(submission)).called(1),
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'sends no shop name when it is left blank',
        build: buildCubit,
        seed: () => documentsDone.copyWith(shopName: '   '),
        act: (cubit) => cubit.next(),
        verify: (_) {
          final sent =
              verify(() => submit(captureAny())).captured.single
                  as TechnicianOnboarding;
          expect(sent.shopName, isNull);
        },
      );

      for (final (reason, failure) in const <(String, Failure)>[
        ('no connection', NetworkFailure()),
        ('rejected photos', InvalidPhotosFailure()),
        ('an unsupported photo', UnsupportedPhotoFailure()),
      ]) {
        blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
          'stays on the documents step and reports $reason',
          setUp: () => when(
            () => submit(any()),
          ).thenAnswer((_) async => Err(failure)),
          build: buildCubit,
          seed: () => documentsDone,
          act: (cubit) => cubit.next(),
          expect: () => [
            documentsDone.copyWith(isSubmitting: true),
            documentsDone.copyWith(failure: () => failure),
          ],
        );
      }

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'clears the previous failure when submitting again',
        build: buildCubit,
        seed: () => documentsDone.copyWith(
          failure: () => const NetworkFailure(),
        ),
        act: (cubit) => cubit.next(),
        expect: () => [
          documentsDone.copyWith(isSubmitting: true),
          documentsDone.copyWith(step: TechnicianStep.done),
        ],
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'ignores next while a submission is in flight',
        build: buildCubit,
        seed: () => documentsDone.copyWith(isSubmitting: true),
        act: (cubit) => cubit.next(),
        expect: () => <TechnicianOnboardingState>[],
        verify: (_) => verifyNever(() => submit(any())),
      );

      blocTest<TechnicianOnboardingCubit, TechnicianOnboardingState>(
        'ignores next once done',
        build: buildCubit,
        seed: () => documentsDone.copyWith(step: TechnicianStep.done),
        act: (cubit) => cubit.next(),
        expect: () => <TechnicianOnboardingState>[],
        verify: (_) => verifyNever(() => submit(any())),
      );
    });
  });
}
