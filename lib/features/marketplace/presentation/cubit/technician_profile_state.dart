part of 'technician_profile_cubit.dart';

enum TechnicianProfileStatus { loading, ready, notFound, failed }

final class TechnicianProfileState extends Equatable {
  const TechnicianProfileState({
    required this.today,
    this.status = TechnicianProfileStatus.loading,
    this.profile,
    this.failure,
  });

  /// When the page opened, for how long ago each review was written.
  final DateTime today;
  final TechnicianProfileStatus status;
  final TechnicianPublicProfile? profile;

  /// Why the page couldn't be fetched.
  final Failure? failure;

  TechnicianProfileState copyWith({
    TechnicianProfileStatus? status,
    TechnicianPublicProfile? profile,
    Failure? Function()? failure,
  }) {
    return TechnicianProfileState(
      today: today,
      status: status ?? this.status,
      profile: profile ?? this.profile,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [today, status, profile, failure];
}
