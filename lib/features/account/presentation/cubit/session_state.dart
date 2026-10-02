part of 'session_cubit.dart';

sealed class SessionState extends Equatable {
  const SessionState();

  @override
  List<Object?> get props => [];
}

/// Restoring the saved session on app start.
final class SessionLoading extends SessionState {
  const SessionLoading();
}

final class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

/// Signed in, but hasn't chosen a role and finished onboarding.
final class SessionNeedsOnboarding extends SessionState {
  const SessionNeedsOnboarding(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}

final class SessionReady extends SessionState {
  const SessionReady({required this.user, required this.profile});

  final AuthUser user;
  final UserProfile profile;

  @override
  List<Object?> get props => [user, profile];
}

/// Signed in, but the profile couldn't be loaded and none is cached.
final class SessionProfileUnavailable extends SessionState {
  const SessionProfileUnavailable(this.user);

  final AuthUser user;

  @override
  List<Object?> get props => [user];
}
