part of 'availability_cubit.dart';

final class AvailabilityState extends Equatable {
  const AvailabilityState({this.until, this.isBusy = false, this.failure});

  /// When the switch turns itself off; null when it is off.
  final DateTime? until;
  final bool isBusy;

  /// Why the last change failed.
  final Failure? failure;

  bool isOnAt(DateTime now) => until?.isAfter(now) ?? false;

  AvailabilityState copyWith({
    DateTime? Function()? until,
    bool? isBusy,
    Failure? Function()? failure,
  }) {
    return AvailabilityState(
      until: until != null ? until() : this.until,
      isBusy: isBusy ?? this.isBusy,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [until, isBusy, failure];
}
