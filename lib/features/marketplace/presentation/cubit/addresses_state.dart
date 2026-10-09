part of 'addresses_cubit.dart';

enum AddressesStatus { loading, ready, failed }

final class AddressesState extends Equatable {
  const AddressesState({
    this.status = AddressesStatus.loading,
    this.addresses = const [],
    this.deleting,
    this.failure,
  });

  final AddressesStatus status;

  /// Oldest first.
  final List<ConsumerAddress> addresses;

  /// The address being deleted, if any.
  final String? deleting;

  /// Why the last delete failed.
  final Failure? failure;

  /// The address book is full.
  bool get isFull => addresses.length >= AddressesCubit.maxAddresses;

  AddressesState copyWith({
    AddressesStatus? status,
    List<ConsumerAddress>? addresses,
    String? Function()? deleting,
    Failure? Function()? failure,
  }) {
    return AddressesState(
      status: status ?? this.status,
      addresses: addresses ?? this.addresses,
      deleting: deleting != null ? deleting() : this.deleting,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, addresses, deleting, failure];
}
