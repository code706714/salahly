import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/network/network_status.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/sync/sync_engine.dart';

class _MockSyncEngine extends Mock implements SyncEngine {}

class _MockAppDatabase extends Mock implements AppDatabase {}

class _ErrorRecorder extends BlocObserver {
  final errors = <Object>[];

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(bloc, error, stackTrace);
  }
}

class _FakeNetwork implements NetworkStatus {
  bool connected = true;
  final controller = StreamController<bool>.broadcast(sync: true);

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<bool> get changes => controller.stream;

  void change({required bool connected}) {
    this.connected = connected;
    controller.add(connected);
  }
}

void main() {
  late _MockSyncEngine engine;
  late _MockAppDatabase database;
  late _FakeNetwork network;
  late LocalChanges changes;
  late StreamController<int> pending;
  final now = DateTime(2026, 10, 2, 9);

  setUp(() {
    engine = _MockSyncEngine();
    database = _MockAppDatabase();
    network = _FakeNetwork();
    changes = LocalChanges();
    pending = StreamController<int>.broadcast(sync: true);
    when(engine.run).thenAnswer((_) async {});
    when(database.watchPendingChanges).thenAnswer((_) => pending.stream);
  });

  SyncCubit build() => SyncCubit(
    engine: engine,
    database: database,
    network: network,
    changes: changes,
    clock: () => now,
  );

  void startIn(FakeAsync async, SyncCubit cubit) {
    unawaited(cubit.start());
    async.flushMicrotasks();
  }

  test('syncs on start and records when', () {
    fakeAsync((async) {
      final cubit = build();
      startIn(async, cubit);

      verify(engine.run).called(1);
      expect(cubit.state.lastSyncedAt, now);
      expect(cubit.state.isSyncing, isFalse);
      expect(cubit.state.isOffline, isFalse);
      unawaited(cubit.close());
    });
  });

  test('syncs shortly after local changes, once for a burst', () {
    fakeAsync((async) {
      final cubit = build();
      startIn(async, cubit);
      clearInteractions(engine);

      changes.notify();
      async.elapse(const Duration(seconds: 1));
      changes.notify();
      async.elapse(const Duration(seconds: 1));
      verifyNever(engine.run);

      async.elapse(const Duration(seconds: 1));
      verify(engine.run).called(1);
      unawaited(cubit.close());
    });
  });

  test('waits for the network, then syncs when it returns', () {
    fakeAsync((async) {
      network.connected = false;
      final cubit = build();
      startIn(async, cubit);
      expect(cubit.state.isOffline, isTrue);

      changes.notify();
      async.elapse(const Duration(minutes: 1));
      verifyNever(engine.run);

      network.change(connected: true);
      async.flushMicrotasks();
      verify(engine.run).called(1);
      expect(cubit.state.isOffline, isFalse);
      unawaited(cubit.close());
    });
  });

  test('marks the server unreachable and retries with growing delays', () {
    fakeAsync((async) {
      when(engine.run).thenThrow(const SocketException('no route'));
      final cubit = build();
      startIn(async, cubit);
      expect(cubit.state.problem, SyncProblem.unreachable);
      expect(cubit.state.isOffline, isTrue);
      clearInteractions(engine);

      async.elapse(const Duration(seconds: 15));
      verify(engine.run).called(1);
      async.elapse(const Duration(seconds: 29));
      verifyNever(engine.run);
      async.elapse(const Duration(seconds: 1));
      verify(engine.run).called(1);

      when(engine.run).thenAnswer((_) async {});
      async.elapse(const Duration(seconds: 60));
      verify(engine.run).called(1);
      expect(cubit.state.problem, isNull);
      unawaited(cubit.close());
    });
  });

  test('reports unexpected failures as errors', () {
    final observer = _ErrorRecorder();
    final previous = Bloc.observer;
    Bloc.observer = observer;
    addTearDown(() => Bloc.observer = previous);
    fakeAsync((async) {
      when(engine.run).thenThrow(StateError('bug'));
      final cubit = build();
      startIn(async, cubit);

      expect(cubit.state.problem, SyncProblem.failed);
      expect(cubit.state.isOffline, isFalse);
      expect(observer.errors.single, isA<StateError>());
      unawaited(cubit.close());
    });
  });

  test('runs again when changes arrive mid-sync', () {
    fakeAsync((async) {
      final gate = Completer<void>();
      var runs = 0;
      when(engine.run).thenAnswer((_) {
        runs++;
        return runs == 1 ? gate.future : Future.value();
      });
      final cubit = build();
      startIn(async, cubit);
      expect(cubit.state.isSyncing, isTrue);

      unawaited(cubit.syncNow());
      gate.complete();
      async.flushMicrotasks();

      expect(runs, 2);
      unawaited(cubit.close());
    });
  });

  test('syncs every few minutes until paused', () {
    fakeAsync((async) {
      final cubit = build();
      startIn(async, cubit);
      clearInteractions(engine);

      async.elapse(const Duration(minutes: 5));
      verify(engine.run).called(1);

      cubit.pause();
      async.elapse(const Duration(minutes: 30));
      verifyNever(engine.run);

      cubit.resume();
      async.flushMicrotasks();
      verify(engine.run).called(1);
      unawaited(cubit.close());
    });
  });

  test('shows how many changes are waiting', () {
    fakeAsync((async) {
      final cubit = build();
      startIn(async, cubit);

      pending.add(3);
      expect(cubit.state.pendingChanges, 3);
      unawaited(cubit.close());
    });
  });
}
