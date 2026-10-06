import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salahly/core/database/tables.dart';

export 'package:salahly/core/database/tables.dart';

part 'app_database.g.dart';

/// The phone's copy of the signed-in technician's records.
///
/// Everything here belongs to one user: [SyncMeta] records who, and the
/// whole database is wiped before anyone else's data is loaded.
@DriftDatabase(
  tables: [
    Customers,
    CustomerUnits,
    Jobs,
    JobItems,
    Payments,
    JobPhotos,
    Outbox,
    PendingUploads,
    SyncMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The database file in the app's private storage.
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'salahly',
      native: const DriftNativeOptions(
        databaseDirectory: getApplicationSupportDirectory,
      ),
    ),
  );

  @override
  int get schemaVersion => 1;

  int _wipes = 0;

  /// How many times the database was wiped. A sync that started before a
  /// wipe sees it changed and must not write what it fetched for the
  /// previous user.
  int get wipeCount => _wipes;

  /// Deletes every row, e.g. on sign-out.
  Future<void> wipe() {
    _wipes++;
    return transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }

  /// Writes [row] whole, replacing the row with the same key. Unlike an
  /// upsert of a data class, fields that are null in [row] end up null.
  Future<void> put<T extends Table, R>(
    TableInfo<T, R> table,
    Insertable<R> row,
  ) => into(table).insert(row, mode: InsertMode.insertOrReplace);

  Future<String?> readMeta(String key) async {
    final entry = await (select(
      syncMeta,
    )..where((meta) => meta.key.equals(key))).getSingleOrNull();
    return entry?.value;
  }

  Future<void> writeMeta(String key, String value) => into(
    syncMeta,
  ).insertOnConflictUpdate(SyncMetaCompanion.insert(key: key, value: value));

  /// How many local changes have not reached the server yet. Changes the
  /// server refused are not counted: they wait for the next edit.
  Stream<int> watchPendingChanges() {
    return customSelect(
      'SELECT (SELECT COUNT(*) FROM outbox WHERE rejected_code IS NULL)'
      ' + (SELECT COUNT(*) FROM pending_uploads) AS pending',
      readsFrom: {outbox, pendingUploads},
    ).watchSingle().map((row) => row.read<int>('pending'));
  }

  /// Records that the row changed locally and must be pushed. Call it in
  /// the same transaction as the write.
  Future<void> enqueue(String entity, String rowId, {required DateTime now}) {
    return into(outbox).insert(
      OutboxCompanion.insert(
        entity: entity,
        rowId: rowId,
        revision: 1,
        queuedAt: now,
      ),
      onConflict: DoUpdate(
        (old) => OutboxCompanion.custom(
          revision: old.revision + const Constant(1),
          rejectedCode: const Constant(null),
        ),
      ),
    );
  }
}
