import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'availability_state.dart';

/// The technician's "available now" switch: while it is on, urgent requests
/// near them reach them. It turns itself off after a few hours.
class AvailabilityCubit extends Cubit<AvailabilityState> {
  AvailabilityCubit(this._requests, {this._clock = DateTime.now})
    : super(const AvailabilityState());

  final TechnicianRequestsRepository _requests;
  final DateTime Function() _clock;

  /// Reads the switch from the server.
  Future<void> load() async {
    final result = await _requests.fetchAvailability();
    if (isClosed) return;
    if (result case Ok(:final value)) {
      emit(state.copyWith(until: () => value));
    }
  }

  /// Switches availability on or off.
  Future<void> toggle({required bool on}) async {
    if (state.isBusy) return;
    emit(state.copyWith(isBusy: true, failure: () => null));
    final result = await _requests.setAvailable(on: on);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(isBusy: false, until: () => value));
      case Err(:final failure):
        emit(state.copyWith(isBusy: false, failure: () => failure));
    }
  }

  /// Whether the switch is on at this moment.
  bool get isOn => state.isOnAt(_clock());
}
