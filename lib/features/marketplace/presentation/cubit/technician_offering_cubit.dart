import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'technician_offering_state.dart';

/// The technician's own services with their starting prices, areas, work
/// days and radius, edited as a whole and saved with one call.
class TechnicianOfferingCubit extends Cubit<TechnicianOfferingState> {
  TechnicianOfferingCubit(this._requests)
    : super(const TechnicianOfferingState());

  final TechnicianRequestsRepository _requests;

  /// Fetches what the technician offers now; again after a failure.
  Future<void> load() async {
    emit(
      state.copyWith(status: OfferingStatus.loading, failure: () => null),
    );
    final result = await _requests.fetchOffering();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: OfferingStatus.editing,
            selectedServiceIds: {
              for (final service in value.services) service.serviceId,
            },
            priceTexts: {
              for (final service in value.services)
                service.serviceId: '${service.startingPricePiastres ~/ 100}',
            },
            areaIds: value.areaIds,
            workDays: value.workDays,
            radiusKm:
                value.radiusKm ?? TechnicianOfferingState.radiusOptions[1],
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(status: OfferingStatus.failed, failure: () => failure),
        );
    }
  }

  /// Takes the catalog's trades, whose services can be offered.
  void useCategories(List<ServiceCategory> categories) =>
      emit(state.copyWith(categories: categories));

  /// Ticking a service for the first time fills in its suggested price.
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

  void areaToggled(String areaId) {
    final areas = {...state.areaIds};
    if (!areas.remove(areaId)) areas.add(areaId);
    emit(state.copyWith(areaIds: areas));
  }

  void workDayToggled(int isoWeekday) {
    final days = {...state.workDays};
    if (!days.remove(isoWeekday)) days.add(isoWeekday);
    emit(state.copyWith(workDays: days));
  }

  void radiusChanged(int km) => emit(state.copyWith(radiusKm: km));

  /// Saves what is on screen, once it is complete. Returns whether it was
  /// saved.
  Future<bool> save() async {
    if (state.status == OfferingStatus.saving) return false;
    if (!state.isValid) {
      emit(state.copyWith(showsErrors: true));
      return false;
    }
    emit(state.copyWith(status: OfferingStatus.saving, failure: () => null));
    final result = await _requests.updateOffering(
      TechnicianOffering(
        services: [
          for (final id in state.offeredServiceIds)
            ServicePrice(
              serviceId: id,
              startingPricePiastres: state.pricePiastres(id)!,
            ),
        ],
        areaIds: state.areaIds,
        workDays: state.workDays,
        radiusKm: state.radiusKm,
      ),
    );
    if (isClosed) return false;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(status: OfferingStatus.saved, handedOver: value));
        return true;
      case Err(:final failure):
        emit(
          state.copyWith(
            status: OfferingStatus.editing,
            failure: () => failure,
          ),
        );
        return false;
    }
  }
}
