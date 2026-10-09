import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'addresses_state.dart';

/// The consumer's address book: adding, editing and deleting addresses.
class AddressesCubit extends Cubit<AddressesState> {
  AddressesCubit(this._requests) : super(const AddressesState());

  /// The most addresses the server keeps for a consumer.
  static const maxAddresses = 10;

  final ConsumerRequestsRepository _requests;

  /// Fetches the address book. A failed refresh keeps the list shown.
  Future<void> load() async {
    final result = await _requests.fetchAddresses();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: AddressesStatus.ready, addresses: value),
        );
      case Err():
        if (state.status != AddressesStatus.ready) {
          emit(state.copyWith(status: AddressesStatus.failed));
        }
    }
  }

  /// Retries a fetch that failed.
  Future<void> retry() async {
    emit(state.copyWith(status: AddressesStatus.loading));
    await load();
  }

  /// Adds an address, or updates the one with [id]. Returns why saving
  /// failed, if it did.
  Future<Failure?> save(ConsumerAddressDraft draft, {String? id}) async {
    final result = await _requests.saveAddress(draft, id: id);
    if (isClosed) return null;
    switch (result) {
      case Ok(:final value):
        final saved = ConsumerAddress(
          id: value,
          label: draft.label,
          areaId: draft.areaId,
          details: draft.details,
        );
        final edited = state.addresses.any((address) => address.id == value);
        emit(
          state.copyWith(
            addresses: edited
                ? [
                    for (final address in state.addresses)
                      address.id == value ? saved : address,
                  ]
                : [...state.addresses, saved],
          ),
        );
        return null;
      case Err(:final failure):
        return failure;
    }
  }

  /// Deletes the address with [id]; a failure shows in [AddressesState].
  Future<void> delete(String id) async {
    emit(state.copyWith(deleting: () => id, failure: () => null));
    final result = await _requests.deleteAddress(id);
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            addresses: [
              for (final address in state.addresses)
                if (address.id != id) address,
            ],
            deleting: () => null,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(deleting: () => null, failure: () => failure));
    }
  }
}
