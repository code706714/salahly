import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/onboarding/domain/entities/consumer_onboarding.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:salahly/features/onboarding/presentation/cubit/onboarding_status.dart';

export 'package:salahly/features/onboarding/presentation/cubit/onboarding_status.dart';

part 'consumer_onboarding_state.dart';

class ConsumerOnboardingCubit extends Cubit<ConsumerOnboardingState> {
  ConsumerOnboardingCubit({
    required this._catalogRepository,
    required this._onboardingRepository,
    required this._locationService,
  }) : super(const ConsumerOnboardingState());

  final CatalogRepository _catalogRepository;
  final OnboardingRepository _onboardingRepository;
  final LocationService _locationService;

  /// Loads the areas and free allowance, then suggests the user's area.
  Future<void> load() async {
    emit(state.copyWith(loadStatus: LoadStatus.loading, failure: () => null));
    final (areas, allowance) = await (
      _catalogRepository.fetchAreas(),
      _onboardingRepository.fetchFreeAllowance(),
    ).wait;
    if (isClosed) return;
    switch ((areas, allowance)) {
      case (Ok(value: final areas), Ok(value: final allowance)):
        emit(
          state.copyWith(
            loadStatus: LoadStatus.ready,
            areas: areas,
            freeRequests: allowance.consumerRequests,
          ),
        );
        await locate();
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(
          state.copyWith(loadStatus: LoadStatus.failed, failure: () => failure),
        );
    }
  }

  /// Picks the area around the device's location.
  Future<void> locate() async {
    emit(state.copyWith(isLocating: true, locationFailure: () => null));
    final result = await _locationService.approximatePosition();
    if (isClosed) return;
    switch (result) {
      case Ok(value: final position):
        final area = nearestArea(state.areas, position);
        emit(
          area == null
              ? state.copyWith(isLocating: false)
              : state.copyWith(
                  isLocating: false,
                  area: area,
                  areaSource: AreaSource.location,
                ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(isLocating: false, locationFailure: () => failure),
        );
    }
  }

  void nameChanged(String value) => emit(state.copyWith(fullName: value));

  void honorificChanged(Honorific value) =>
      emit(state.copyWith(honorific: value));

  void areaPicked(ServiceArea area) => emit(
    state.copyWith(
      area: area,
      areaSource: AreaSource.manual,
      locationFailure: () => null,
    ),
  );

  Future<void> submit() async {
    if (state.isSubmitting || state.isDone) return;
    if (!state.isComplete) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    emit(state.copyWith(isSubmitting: true, failure: () => null));
    final result = await _onboardingRepository.completeConsumerOnboarding(
      ConsumerOnboarding(
        fullName: normalizeName(state.fullName),
        honorific: state.honorific!,
        areaId: state.area!.id,
      ),
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() || Err(failure: AlreadyOnboardedFailure()) => state.copyWith(
        isSubmitting: false,
        isDone: true,
      ),
      Err(:final failure) => state.copyWith(
        isSubmitting: false,
        failure: () => failure,
      ),
    });
  }
}
