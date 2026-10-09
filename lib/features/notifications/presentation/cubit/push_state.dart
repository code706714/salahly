part of 'push_cubit.dart';

/// Where push stands on this phone.
enum PushStatus {
  /// Not looked at yet.
  unknown,

  /// This build has no Firebase set up: nothing to do.
  unavailable,

  /// The system hasn't asked the person yet: explain, then ask.
  needsPermission,

  /// The person said not now; asked again next time the app opens.
  deferred,

  /// The person refused in the system's dialog.
  denied,

  /// The phone is registered and pushes arrive.
  active,
}

/// A message that arrived or was tapped. Two equal messages are still two
/// events, so listeners see each one.
final class PushEvent {
  const PushEvent(this.notice);

  final PushNotice notice;
}

final class PushState extends Equatable {
  const PushState({
    this.status = PushStatus.unknown,
    this.received,
    this.opened,
  });

  final PushStatus status;

  /// The latest message that arrived while the app was open.
  final PushEvent? received;

  /// The latest message the person tapped.
  final PushEvent? opened;

  PushState copyWith({
    PushStatus? status,
    PushEvent? received,
    PushEvent? opened,
  }) => PushState(
    status: status ?? this.status,
    received: received ?? this.received,
    opened: opened ?? this.opened,
  );

  @override
  List<Object?> get props => [status, received, opened];
}
