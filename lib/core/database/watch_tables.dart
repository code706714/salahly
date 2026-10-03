import 'dart:async';

import 'package:drift/drift.dart';

/// Emits [load]'s result now and again after every write to [tables].
///
/// Bursts of writes (a sync applying many rows) cause one reload, not one
/// per write.
Stream<T> watchTables<T>(
  DatabaseConnectionUser db,
  Set<ResultSetImplementation<dynamic, dynamic>> tables,
  Future<T> Function() load,
) {
  late final StreamController<T> controller;
  StreamSubscription<Set<TableUpdate>>? updates;
  var loading = false;
  var stale = false;

  Future<void> reload() async {
    if (loading) {
      stale = true;
      return;
    }
    loading = true;
    do {
      stale = false;
      try {
        final value = await load();
        if (!controller.isClosed) controller.add(value);
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    } while (stale && !controller.isClosed);
    loading = false;
  }

  controller = StreamController<T>(
    onListen: () {
      updates = db
          .tableUpdates(TableUpdateQuery.onAllTables(tables))
          .listen((_) => unawaited(reload()));
      unawaited(reload());
    },
    onCancel: () => updates?.cancel(),
  );
  return controller.stream;
}

/// SQLite's julianday() as a UTC time.
DateTime fromJulianDay(double julianDay) => DateTime.fromMillisecondsSinceEpoch(
  ((julianDay - 2440587.5) * Duration.millisecondsPerDay).round(),
  isUtc: true,
);
