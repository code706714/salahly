part of 'admin_session_cubit.dart';

sealed class AdminSessionState extends Equatable {
  const AdminSessionState();

  @override
  List<Object?> get props => [];
}

/// Restoring the saved session, or asking the server who this is.
final class AdminSessionChecking extends AdminSessionState {
  const AdminSessionChecking();
}

final class AdminSessionSignedOut extends AdminSessionState {
  const AdminSessionSignedOut();
}

/// Signed in as someone the server does not accept as an admin. They are
/// signed out; the screen says why.
final class AdminSessionNoAccess extends AdminSessionState {
  const AdminSessionNoAccess();
}

/// Signed in, but the server could not be asked.
final class AdminSessionUnavailable extends AdminSessionState {
  const AdminSessionUnavailable(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class AdminSessionReady extends AdminSessionState {
  const AdminSessionReady();
}
