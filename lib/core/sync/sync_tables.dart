import 'package:drift/drift.dart';
import 'package:salahly/core/database/app_database.dart';

/// Names the server uses for each synced table.
abstract final class SyncEntity {
  static const customers = 'customers';
  static const customerUnits = 'customer_units';
  static const jobs = 'jobs';
  static const jobItems = 'job_items';
  static const payments = 'payments';
  static const jobPhotos = 'job_photos';
}

/// Converts rows to and from the server's JSON. Times always travel in
/// UTC: a local time without an offset would be read as UTC by Postgres.
class SyncSerializer extends ValueSerializer {
  const SyncSerializer();

  static const _defaults = ValueSerializer.defaults(
    serializeDateTimeValuesAsString: true,
  );

  @override
  T fromJson<T>(dynamic json) => _defaults.fromJson<T>(json);

  @override
  dynamic toJson<T>(T value) => switch (value) {
    final DateTime time => time.toUtc().toIso8601String(),
    _ => _defaults.toJson<T>(value),
  };
}

/// One synced table: how to find a row and convert it.
final class SyncTable<R> {
  const SyncTable(this.entity, this.table, this._fromJson);

  final String entity;
  final TableInfo<Table, R> table;
  final R Function(Map<String, dynamic> json, {ValueSerializer? serializer})
  _fromJson;

  static const _serializer = SyncSerializer();

  GeneratedColumn<String> get _id =>
      table.columnsByName['id']! as GeneratedColumn<String>;

  R fromServer(Map<String, dynamic> json) =>
      _fromJson(json, serializer: _serializer);

  Map<String, dynamic> toServer(R row) =>
      (row as DataClass).toJson(serializer: _serializer);

  Future<R?> find(DatabaseConnectionUser db, String id) =>
      (db.select(table)..where((_) => _id.equals(id))).getSingleOrNull();

  /// Writes [row] whole: fields that are null on the server become null
  /// here too.
  Future<void> upsert(DatabaseConnectionUser db, R row) => db
      .into(table)
      .insert(row as Insertable<R>, mode: InsertMode.insertOrReplace);

  Future<void> deleteRow(DatabaseConnectionUser db, String id) =>
      (db.delete(table)..where((_) => _id.equals(id))).go();
}

/// Every synced table, parents before children: pushing in this order
/// means a row's parent always reaches the server first.
List<SyncTable<Object?>> syncTables(AppDatabase db) => [
  SyncTable(SyncEntity.customers, db.customers, CustomerRow.fromJson),
  SyncTable(
    SyncEntity.customerUnits,
    db.customerUnits,
    CustomerUnitRow.fromJson,
  ),
  SyncTable(SyncEntity.jobs, db.jobs, JobRow.fromJson),
  SyncTable(SyncEntity.jobItems, db.jobItems, JobItemRow.fromJson),
  SyncTable(SyncEntity.payments, db.payments, PaymentRow.fromJson),
  SyncTable(SyncEntity.jobPhotos, db.jobPhotos, JobPhotoRow.fromJson),
];
