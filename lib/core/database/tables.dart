import 'dart:convert';

import 'package:drift/drift.dart';

// The technician's records, mirroring the server tables of the same name
// (minus technician_id and the sync bookkeeping, which never leave the
// server). Enums are stored as the server's text values; each feature's
// data layer maps them to its domain types.

@DataClassName('CustomerRow')
class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get areaId => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CustomerUnitRow')
@TableIndex(name: 'customer_units_customer_idx', columns: {#customerId})
class CustomerUnits extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get brand => text().nullable()();
  RealColumn get capacityHp => real().nullable()();
  TextColumn get room => text().nullable()();
  IntColumn get installedYear => integer().nullable()();

  /// A calendar date, `yyyy-MM-dd`.
  TextColumn get nextServiceOn => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JobRow')
@TableIndex(name: 'jobs_customer_idx', columns: {#customerId})
@TableIndex(name: 'jobs_scheduled_idx', columns: {#scheduledAt})
class Jobs extends Table {
  TextColumn get id => text()();
  TextColumn get customerId => text()();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get description => text().nullable()();
  DateTimeColumn get scheduledAt => dateTime().nullable()();
  IntColumn get durationMinutes => integer().withDefault(const Constant(60))();
  TextColumn get address => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('unconfirmed'))();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  DateTimeColumn get paidAt => dateTime().nullable()();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get quoteStatus => text().withDefault(const Constant('none'))();
  DateTimeColumn get quoteSentAt => dateTime().nullable()();
  IntColumn get quoteValidDays => integer().withDefault(const Constant(3))();

  /// A calendar date, `yyyy-MM-dd`.
  TextColumn get paymentPromisedOn => text().nullable()();
  IntColumn get invoiceNumber => integer().nullable()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JobItemRow')
@TableIndex(name: 'job_items_job_idx', columns: {#jobId})
class JobItems extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  TextColumn get title => text()();
  IntColumn get unitPricePiastres => integer()();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PaymentRow')
@TableIndex(name: 'payments_job_idx', columns: {#jobId})
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  IntColumn get amountPiastres => integer()();
  TextColumn get method => text()();
  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('JobPhotoRow')
@TableIndex(name: 'job_photos_job_idx', columns: {#jobId})
class JobPhotos extends Table {
  TextColumn get id => text()();
  TextColumn get jobId => text()();
  TextColumn get kind => text()();
  TextColumn get storagePath => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local edits waiting to reach the server, one entry per row.
///
/// [revision] grows with every edit, so a push only clears the entry when
/// nothing changed the row while the push was in flight.
@DataClassName('OutboxEntry')
class Outbox extends Table {
  TextColumn get entity => text()();
  TextColumn get rowId => text()();
  IntColumn get revision => integer()();
  DateTimeColumn get queuedAt => dateTime()();

  /// Why the server refused the last push. Set entries wait for the next
  /// local edit instead of being retried.
  TextColumn get rejectedCode => text().nullable()();

  @override
  Set<Column> get primaryKey => {entity, rowId};
}

/// Job photos saved on the phone and not uploaded yet. Their row joins the
/// outbox once the file is on the server.
@DataClassName('PendingUpload')
class PendingUploads extends Table {
  TextColumn get photoId => text()();
  TextColumn get storagePath => text()();
  DateTimeColumn get queuedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {photoId};
}

/// Small key-value facts about the local copy: whose data it is and how
/// far it has pulled.
@DataClassName('SyncMetaEntry')
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// A list of strings, stored as a JSON array and sent to the server as one.
class StringListConverter extends TypeConverter<List<String>, String>
    with JsonTypeConverter2<List<String>, String, List<Object?>> {
  const StringListConverter();

  @override
  List<String> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<Object?>).cast<String>();

  @override
  String toSql(List<String> value) => jsonEncode(value);

  @override
  List<String> fromJson(List<Object?> json) => json.cast<String>();

  @override
  List<Object?> toJson(List<String> value) => value;
}
