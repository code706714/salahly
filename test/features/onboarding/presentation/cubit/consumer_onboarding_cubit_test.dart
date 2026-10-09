import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/onboarding/domain/entities/consumer_onboarding.dart';
import 'package:salahly/features/onboarding/domain/entities/free_allowance.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/presentation/cubit/consumer_onboarding_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

const _allowance = FreeAllowance(consumerRequests: 3, technicianJobs: 5);

const _ready = ConsumerOnboardingState(
  loadStatus: LoadStatus.ready,
  areas: TestAreas.all,
  freeRequests: 3,
);

const _filled = ConsumerOnboardingState(
  loadStatus: LoadStatus.ready,
  areas: TestAreas.all,
  freeRequests: 3,
  fullName: '  منى   عبد الرحمن ',
  honorific: Honorific.ms,
  area: TestAreas.nasrCity,
);

void main() {
  late MockCatalogRepository catalogRepository;
  late MockOnboardingRepository onboardingRepository;
  late MockLocationService locationService;

  ConsumerOnboardingCubit buildCubit() => ConsumerOnboardingCubit(
    catalogRepository: catalogRepository,
    onboardingRepository: onboardingRepository,
    locationService: locationService,
  );

  void stubPosition(Result<GeoPoint> result) => when(
    () => locationService.approximatePosition(),
  ).thenAnswer((_) async => result);

  void stubSubmit(Result<void> result) => when(
    () => onboardingRepository.completeConsumerOnboarding(any()),
  ).thenAnswer((_) async => result);

  setUpAll(() {
    registerFallbackValue(
      const ConsumerOnboarding(
        fullName: 'منى',
        honorific: Honorific.ms,
        areaId: 'nasr_city',
      ),
    );
  });

  setUp(() {
    catalogRepository = MockCatalogRepository();
    onboardingRepository = MockOnboardingRepository();
    locationService = MockLocationService();
    when(
      () => catalogRepository.fetchAreas(),
    ).thenAnswer((_) async => const Ok(TestAreas.all));
    when(
      () => onboardingRepository.fetchFreeAllowance(),
    ).thenAnswer((_) async => const Ok(_allowance));
    stubPosition(const Ok(TestPositions.inMaadi));
    stubSubmit(const Ok(null));
  });

  group('ConsumerOnboardingCubit', () {
    test('starts loading with an empty form', () async {
      final cubit = buildCubit();

      expect(cubit.state, const ConsumerOnboardingState());
      expect(cubit.state.loadStatus, LoadStatus.loading);
      await cubit.close();
    });

    group('load', () {
      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'shows the areas and free requests, then suggests the nearby area',
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConsumerOnboardingState(),
          _ready,
          _ready.copyWith(isLocating: true),
          _ready.copyWith(
            area: TestAreas.maadi,
            areaSource: AreaSource.location,
          ),
        ],
      );

      test('fetches the areas and the free allowance in parallel', () async {
        final areas = Completer<Result<List<ServiceArea>>>();
        final allowance = Completer<Result<FreeAllowance>>();
        when(
          () => catalogRepository.fetchAreas(),
        ).thenAnswer((_) => areas.future);
        when(
          () => onboardingRepository.fetchFreeAllowance(),
        ).thenAnswer((_) => allowance.future);
        final cubit = buildCubit();

        final loading = cubit.load();

        verify(() => catalogRepository.fetchAreas()).called(1);
        verify(() => onboardingRepository.fetchFreeAllowance()).called(1);
        allowance.complete(const Ok(_allowance));
        areas.complete(const Ok(TestAreas.all));
        await loading;
        expect(cubit.state.loadStatus, LoadStatus.ready);
        await cubit.close();
      });

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'fails without locating when the areas cannot be fetched',
        setUp: () => when(
          () => catalogRepository.fetchAreas(),
        ).thenAnswer((_) async => const Err(NetworkFailure())),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConsumerOnboardingState(),
          const ConsumerOnboardingState(
            loadStatus: LoadStatus.failed,
            failure: NetworkFailure(),
          ),
        ],
        verify: (_) => verifyNever(() => locationService.approximatePosition()),
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'fails when the free allowance cannot be fetched',
        setUp: () => when(
          () => onboardingRepository.fetchFreeAllowance(),
        ).thenAnswer((_) async => const Err(UnexpectedFailure())),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConsumerOnboardingState(),
          const ConsumerOnboardingState(
            loadStatus: LoadStatus.failed,
            failure: UnexpectedFailure(),
          ),
        ],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'clears the failure when retried',
        build: buildCubit,
        seed: () => const ConsumerOnboardingState(
          loadStatus: LoadStatus.failed,
          failure: NetworkFailure(),
        ),
        act: (cubit) => cubit.load(),
        expect: () => [
          const ConsumerOnboardingState(),
          _ready,
          _ready.copyWith(isLocating: true),
          _ready.copyWith(
            area: TestAreas.maadi,
            areaSource: AreaSource.location,
          ),
        ],
      );
    });

    group('locate', () {
      const failures = [
        (
          'permission was denied',
          LocationPermissionFailure(permanently: false),
        ),
        (
          'permission was denied for good',
          LocationPermissionFailure(permanently: true),
        ),
        ('location services are off', LocationDisabledFailure()),
      ];
      for (final (reason, failure) in failures) {
        blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
          'reports that $reason and leaves the area unchosen',
          setUp: () => stubPosition(Err(failure)),
          build: buildCubit,
          seed: () => _ready,
          act: (cubit) => cubit.locate(),
          expect: () => [
            _ready.copyWith(isLocating: true),
            _ready.copyWith(locationFailure: () => failure),
          ],
        );
      }

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'picks the nearest area within 25 km',
        build: buildCubit,
        seed: () => _ready,
        act: (cubit) => cubit.locate(),
        expect: () => [
          _ready.copyWith(isLocating: true),
          _ready.copyWith(
            area: TestAreas.maadi,
            areaSource: AreaSource.location,
          ),
        ],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'keeps the chosen area when every area is over 25 km away',
        setUp: () => stubPosition(const Ok(TestPositions.alexandria)),
        build: buildCubit,
        seed: () => _ready.copyWith(area: TestAreas.zamalek),
        act: (cubit) => cubit.locate(),
        expect: () => [
          _ready.copyWith(area: TestAreas.zamalek, isLocating: true),
          _ready.copyWith(area: TestAreas.zamalek),
        ],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'clears the previous location failure when retried',
        build: buildCubit,
        seed: () => _ready.copyWith(
          locationFailure: () => const LocationDisabledFailure(),
        ),
        act: (cubit) => cubit.locate(),
        expect: () => [
          _ready.copyWith(isLocating: true),
          _ready.copyWith(
            area: TestAreas.maadi,
            areaSource: AreaSource.location,
          ),
        ],
      );
    });

    group('form', () {
      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'nameChanged updates the name',
        build: buildCubit,
        seed: () => _ready,
        act: (cubit) => cubit.nameChanged('منى'),
        expect: () => [_ready.copyWith(fullName: 'منى')],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'honorificChanged updates the honorific',
        build: buildCubit,
        seed: () => _ready,
        act: (cubit) => cubit.honorificChanged(Honorific.mr),
        expect: () => [_ready.copyWith(honorific: Honorific.mr)],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'areaPicked marks the area as chosen by hand and clears the '
        'location failure',
        build: buildCubit,
        seed: () => _ready.copyWith(
          area: TestAreas.maadi,
          areaSource: AreaSource.location,
          locationFailure: () => const LocationDisabledFailure(),
        ),
        act: (cubit) => cubit.areaPicked(TestAreas.zamalek),
        expect: () => [
          _ready.copyWith(
            area: TestAreas.zamalek,
            areaSource: AreaSource.manual,
          ),
        ],
      );
    });

    group('validation', () {
      test('is complete with a name, an honorific and an area', () {
        expect(_filled.isComplete, isTrue);
      });

      test('needs at least two letters once spaces are trimmed', () {
        expect(_filled.copyWith(fullName: '  م  ').isNameValid, isFalse);
        expect(_filled.copyWith(fullName: '  مي  ').isNameValid, isTrue);
      });

      test('is incomplete while any field is missing', () {
        const missingName = ConsumerOnboardingState(
          honorific: Honorific.ms,
          area: TestAreas.nasrCity,
        );
        const missingHonorific = ConsumerOnboardingState(
          fullName: 'منى عبد الرحمن',
          area: TestAreas.nasrCity,
        );
        const missingArea = ConsumerOnboardingState(
          fullName: 'منى عبد الرحمن',
          honorific: Honorific.ms,
        );

        expect(missingName.isComplete, isFalse);
        expect(missingHonorific.isComplete, isFalse);
        expect(missingArea.isComplete, isFalse);
      });
    });

    group('submit', () {
      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'flags the missing fields instead of submitting',
        build: buildCubit,
        seed: () => _ready.copyWith(fullName: 'منى'),
        act: (cubit) => cubit.submit(),
        expect: () => [_ready.copyWith(fullName: 'منى', showErrors: true)],
        verify: (_) => verifyNever(
          () => onboardingRepository.completeConsumerOnboarding(any()),
        ),
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'sends the normalized name, the honorific and the area',
        build: buildCubit,
        seed: () => _filled,
        act: (cubit) => cubit.submit(),
        expect: () => [
          _filled.copyWith(isSubmitting: true),
          _filled.copyWith(isDone: true),
        ],
        verify: (_) => verify(
          () => onboardingRepository.completeConsumerOnboarding(
            const ConsumerOnboarding(
              fullName: 'منى عبد الرحمن',
              honorific: Honorific.ms,
              areaId: 'nasr_city',
            ),
          ),
        ).called(1),
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'treats an already onboarded account as done',
        setUp: () => stubSubmit(const Err(AlreadyOnboardedFailure())),
        build: buildCubit,
        seed: () => _filled,
        act: (cubit) => cubit.submit(),
        expect: () => [
          _filled.copyWith(isSubmitting: true),
          _filled.copyWith(isDone: true),
        ],
      );

      blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
        'shows a network failure and clears it on the next attempt',
        setUp: () => stubSubmit(const Err(NetworkFailure())),
        build: buildCubit,
        seed: () => _filled,
        act: (cubit) async {
          await cubit.submit();
          stubSubmit(const Ok(null));
          await cubit.submit();
        },
        expect: () => [
          _filled.copyWith(isSubmitting: true),
          _filled.copyWith(failure: () => const NetworkFailure()),
          _filled.copyWith(isSubmitting: true),
          _filled.copyWith(isDone: true),
        ],
      );

      for (final (moment, seed) in [
        (
          'while a submission is in flight',
          _filled.copyWith(isSubmitting: true),
        ),
        ('once done', _filled.copyWith(isDone: true)),
      ]) {
        blocTest<ConsumerOnboardingCubit, ConsumerOnboardingState>(
          'ignores taps $moment',
          build: buildCubit,
          seed: () => seed,
          act: (cubit) => cubit.submit(),
          expect: () => <ConsumerOnboardingState>[],
          verify: (_) => verifyNever(
            () => onboardingRepository.completeConsumerOnboarding(any()),
          ),
        );
      }
    });
  });
}
