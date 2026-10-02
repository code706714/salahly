import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/geo/geo_point.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:salahly/features/onboarding/domain/usecases/submit_technician_onboarding.dart';
import 'package:salahly/features/onboarding/presentation/cubit/onboarding_status.dart';

export 'package:salahly/features/onboarding/presentation/cubit/onboarding_status.dart';

part 'technician_onboarding_state.dart';

/// The four-step technician sign-up: profile, services and prices, work
/// area, then ID photos.
class TechnicianOnboardingCubit extends Cubit<TechnicianOnboardingState> {
  TechnicianOnboardingCubit({
    required this._catalogRepository,
    required this._onboardingRepository,
    required this._locationService,
    required this._submitOnboarding,
  }) : super(const TechnicianOnboardingState());

  final CatalogRepository _catalogRepository;
  final OnboardingRepository _onboardingRepository;
  final LocationService _locationService;
  final SubmitTechnicianOnboarding _submitOnboarding;

  Future<void> load() async {
    emit(state.copyWith(loadStatus: LoadStatus.loading, failure: () => null));
    final (categories, areas, allowance) = await (
      _catalogRepository.fetchCategories(),
      _catalogRepository.fetchAreas(),
      _onboardingRepository.fetchFreeAllowance(),
    ).wait;
    if (isClosed) return;
    switch ((categories, areas, allowance)) {
      case (
        Ok(value: final categories),
        Ok(value: final areas),
        Ok(value: final allowance),
      ):
        emit(
          state.copyWith(
            loadStatus: LoadStatus.ready,
            categories: categories,
            areas: areas,
            freeJobs: allowance.technicianJobs,
          ),
        );
      case (Err(:final failure), _, _) ||
          (_, Err(:final failure), _) ||
          (_, _, Err(:final failure)):
        emit(
          state.copyWith(loadStatus: LoadStatus.failed, failure: () => failure),
        );
    }
  }

  /// Moves to the next step when the current one is complete, and submits
  /// after the last one.
  Future<void> next() async {
    if (state.isSubmitting) return;
    if (!state.isCurrentStepValid) {
      emit(state.copyWith(showErrors: true));
      return;
    }
    switch (state.step) {
      case TechnicianStep.documents:
        await _submit();
      case TechnicianStep.done:
        return;
      case TechnicianStep.profile:
      case TechnicianStep.services:
      case TechnicianStep.location:
        final next = TechnicianStep.values[state.step.index + 1];
        emit(
          state.copyWith(step: next, showErrors: false, failure: () => null),
        );
        if (next == TechnicianStep.location && state.baseArea == null) {
          await locate();
        }
    }
  }

  /// Goes one step back. Returns false on the first step, so the page
  /// can leave onboarding instead.
  bool back() {
    if (state.isSubmitting) return true;
    switch (state.step) {
      case TechnicianStep.profile:
        return false;
      case TechnicianStep.done:
        return true;
      case TechnicianStep.services:
      case TechnicianStep.location:
      case TechnicianStep.documents:
        emit(
          state.copyWith(
            step: TechnicianStep.values[state.step.index - 1],
            showErrors: false,
            failure: () => null,
          ),
        );
        return true;
    }
  }

  void avatarPicked(String path) => emit(state.copyWith(avatarPath: path));

  void nameChanged(String value) => emit(state.copyWith(fullName: value));

  void shopNameChanged(String value) => emit(state.copyWith(shopName: value));

  void yearsChanged(String value) => emit(state.copyWith(yearsText: value));

  /// Checking a service for the first time fills in the suggested price.
  void serviceToggled(CatalogService service) {
    final selected = {...state.selectedServiceIds};
    final prices = {...state.priceTexts};
    if (!selected.remove(service.id)) {
      selected.add(service.id);
      prices.putIfAbsent(
        service.id,
        () => '${service.suggestedPricePiastres ~/ 100}',
      );
    }
    emit(state.copyWith(selectedServiceIds: selected, priceTexts: prices));
  }

  void priceChanged(String serviceId, String value) => emit(
    state.copyWith(priceTexts: {...state.priceTexts, serviceId: value}),
  );

  /// Uses the device location as the base and picks its area.
  Future<void> locate() async {
    emit(state.copyWith(isLocating: true, locationFailure: () => null));
    final result = await _locationService.approximatePosition();
    if (isClosed) return;
    switch (result) {
      case Ok(value: final position):
        final area = nearestArea(state.areas, position);
        if (area == null) {
          emit(state.copyWith(isLocating: false));
        } else {
          _setBase(area, position, AreaSource.location);
        }
      case Err(:final failure):
        emit(
          state.copyWith(isLocating: false, locationFailure: () => failure),
        );
    }
  }

  /// A hand-picked base is placed at the area's center.
  void basePicked(ServiceArea area) =>
      _setBase(area, area.center, AreaSource.manual);

  void radiusChanged(int km) => emit(state.copyWith(radiusKm: km));

  void areaToggled(String areaId) {
    final areaIds = {...state.areaIds};
    if (!areaIds.remove(areaId)) areaIds.add(areaId);
    emit(state.copyWith(areaIds: areaIds));
  }

  void workDayToggled(int isoWeekday) {
    final days = {...state.workDays};
    if (!days.remove(isoWeekday)) days.add(isoWeekday);
    emit(state.copyWith(workDays: days));
  }

  void documentPicked(DocumentSlot slot, String path) => emit(
    state.copyWith(documents: {...state.documents, slot: path}),
  );

  void _setBase(ServiceArea area, GeoPoint location, AreaSource source) {
    emit(
      state.copyWith(
        isLocating: false,
        baseArea: area,
        baseLocation: location,
        baseSource: source,
        locationFailure: () => null,
        areaIds: state.areaIds.isEmpty ? {area.id} : null,
      ),
    );
  }

  Future<void> _submit() async {
    emit(state.copyWith(isSubmitting: true, failure: () => null));
    final shopName = normalizeName(state.shopName);
    final result = await _submitOnboarding(
      TechnicianOnboarding(
        fullName: normalizeName(state.fullName),
        shopName: shopName.isEmpty ? null : shopName,
        yearsExperience: state.yearsExperience!,
        baseAreaId: state.baseArea!.id,
        baseLocation: state.baseLocation!,
        serviceRadiusKm: state.radiusKm,
        workDays: state.workDays,
        areaIds: state.areaIds,
        startingPricesPiastres: {
          for (final id in state.selectedServiceIds)
            id: state.pricePiastres(id)!,
        },
        photos: TechnicianDocuments(
          avatar: state.avatarPath!,
          idFront: state.documents[DocumentSlot.idFront]!,
          idBack: state.documents[DocumentSlot.idBack]!,
          selfieWithId: state.documents[DocumentSlot.selfieWithId]!,
        ),
      ),
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(isSubmitting: false, step: TechnicianStep.done),
      Err(:final failure) => state.copyWith(
        isSubmitting: false,
        failure: () => failure,
      ),
    });
  }
}
