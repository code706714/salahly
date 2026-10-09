part of 'sync_cubit.dart';

enum SyncProblem {
  /// The phone has a network but the server could not be reached.
  unreachable,

  /// The server answered with an error; logged for us to fix.
  failed,
}

final class SyncState extends Equatable {
  const SyncState({
    this.hasNetwork = true,
    this.isSyncing = false,
    this.pendingChanges = 0,
    this.lastSyncedAt,
    this.problem,
  });

  final bool hasNetwork;
  final bool isSyncing;

  /// Local changes not on the server yet.
  final int pendingChanges;
  final DateTime? lastSyncedAt;
  final SyncProblem? problem;

  /// Whether changes are currently kept on the phone only.
  bool get isOffline => !hasNetwork || problem == SyncProblem.unreachable;

  SyncState copyWith({
    bool? hasNetwork,
    bool? isSyncing,
    int? pendingChanges,
    DateTime? lastSyncedAt,
    SyncProblem? Function()? problem,
  }) {
    return SyncState(
      hasNetwork: hasNetwork ?? this.hasNetwork,
      isSyncing: isSyncing ?? this.isSyncing,
      pendingChanges: pendingChanges ?? this.pendingChanges,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      problem: problem == null ? this.problem : problem(),
    );
  }

  @override
  List<Object?> get props => [
    hasNetwork,
    isSyncing,
    pendingChanges,
    lastSyncedAt,
    problem,
  ];
}
