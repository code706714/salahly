import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/network/network_status.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_engine.dart';

part 'sync_state.dart';

/// Decides when to sync and reports how it went.
///
/// Syncs on start, shortly after local changes, when the network returns,
/// when the app comes back to the foreground and every few minutes. A
/// failed sync is retried with growing delays.
class SyncCubit extends Cubit<SyncState> {
  SyncCubit({
    required this._engine,
    required this._database,
    required this._network,
    required this._changes,
    this._debounce = const Duration(seconds: 2),
    this._period = const Duration(minutes: 5),
    this._clock = DateTime.now,
  }) : super(const SyncState());

  static const _maxRetryDelay = Duration(minutes: 5);

  final SyncEngine _engine;
  final AppDatabase _database;
  final NetworkStatus _network;
  final LocalChanges _changes;
  final Duration _debounce;
  final Duration _period;
  final DateTime Function() _clock;

  final _subscriptions = <StreamSubscription<Object?>>[];
  Timer? _soon;
  Timer? _periodic;
  int _failures = 0;
  bool _running = false;
  bool _runAgain = false;

  Future<void> start() async {
    _subscriptions
      ..add(_network.changes.listen(_onNetworkChanged))
      ..add(_changes.stream.listen((_) => _syncSoon(_debounce)))
      ..add(
        _database.watchPendingChanges().listen(
          (pending) => emit(state.copyWith(pendingChanges: pending)),
        ),
      );
    final hasNetwork = await _network.isConnected();
    if (isClosed) return;
    emit(state.copyWith(hasNetwork: hasNetwork));
    resume();
  }

  /// The app came to the foreground.
  void resume() {
    _periodic?.cancel();
    _periodic = Timer.periodic(_period, (_) => unawaited(syncNow()));
    unawaited(syncNow());
  }

  /// The app went to the background; stop waking up for periodic syncs.
  void pause() {
    _periodic?.cancel();
    _periodic = null;
  }

  Future<void> syncNow() async {
    _soon?.cancel();
    if (isClosed || !state.hasNetwork) return;
    if (_running) {
      _runAgain = true;
      return;
    }
    _running = true;
    emit(state.copyWith(isSyncing: true));
    try {
      await _engine.run();
      _failures = 0;
      if (isClosed) return;
      emit(state.copyWith(lastSyncedAt: _clock(), problem: () => null));
    } on Object catch (error, stackTrace) {
      if (isClosed) return;
      _failures++;
      final unreachable = isNetworkError(error);
      if (!unreachable) addError(error, stackTrace);
      emit(
        state.copyWith(
          problem: () =>
              unreachable ? SyncProblem.unreachable : SyncProblem.failed,
        ),
      );
      _syncSoon(_retryDelay());
    } finally {
      _running = false;
      if (!isClosed) emit(state.copyWith(isSyncing: false));
    }
    if (_runAgain) {
      _runAgain = false;
      await syncNow();
    }
  }

  Duration _retryDelay() {
    final seconds = 15 * pow(2, min(_failures - 1, 5));
    return Duration(
      seconds: min(seconds.toInt(), _maxRetryDelay.inSeconds),
    );
  }

  void _syncSoon(Duration delay) {
    _soon?.cancel();
    _soon = Timer(delay, () => unawaited(syncNow()));
  }

  void _onNetworkChanged(bool hasNetwork) {
    emit(state.copyWith(hasNetwork: hasNetwork));
    if (hasNetwork) unawaited(syncNow());
  }

  @override
  Future<void> close() async {
    _soon?.cancel();
    _periodic?.cancel();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
