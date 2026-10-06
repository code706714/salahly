import 'package:drift/drift.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/database/watch_tables.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_tables.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/customers/data/mappers/customer_mapper.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';
import 'package:uuid/uuid.dart';

/// Customers in the phone's database. Every write is queued for sync in
/// the same transaction.
class DriftCustomersRepository implements CustomersRepository {
  DriftCustomersRepository({
    required this._database,
    required this._changes,
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  });

  final AppDatabase _database;
  final LocalChanges _changes;
  final Uuid _uuid;
  final DateTime Function() _clock;

  @override
  Stream<List<CustomerSummary>> watchCustomers({required DateTime today}) {
    final db = _database;
    return db
        .customSelect(
          """
WITH job_money AS (
  SELECT j.id, j.customer_id, j.status, j.finished_at, j.scheduled_at,
    j.updated_at,
    COALESCE((SELECT SUM(unit_price_piastres * quantity) FROM job_items i
      WHERE i.job_id = j.id AND i.deleted_at IS NULL), 0) AS total,
    COALESCE((SELECT SUM(amount_piastres) FROM payments p
      WHERE p.job_id = j.id AND p.deleted_at IS NULL), 0) AS paid
  FROM jobs j
  WHERE j.deleted_at IS NULL AND j.status <> 'cancelled'
),
owed AS (
  SELECT * FROM job_money WHERE status = 'finished' AND total > paid
)
SELECT c.*,
  (SELECT COUNT(*) FROM customer_units u
    WHERE u.customer_id = c.id AND u.deleted_at IS NULL) AS unit_count,
  (SELECT MIN(next_service_on) FROM customer_units u
    WHERE u.customer_id = c.id AND u.deleted_at IS NULL) AS next_service,
  (SELECT COUNT(*) FROM job_money m WHERE m.customer_id = c.id) AS job_count,
  (SELECT COALESCE(SUM(total - paid), 0) FROM owed o
    WHERE o.customer_id = c.id) AS owed,
  (SELECT MIN(julianday(finished_at)) FROM owed o
    WHERE o.customer_id = c.id) AS owed_since,
  (SELECT MAX(julianday(finished_at)) FROM job_money m
    WHERE m.customer_id = c.id) AS last_finished,
  (SELECT MIN(julianday(scheduled_at)) FROM job_money m
    WHERE m.customer_id = c.id
      AND m.status IN ('unconfirmed', 'confirmed', 'started')
      AND julianday(m.scheduled_at) >= julianday(?)) AS next_scheduled
FROM customers c
WHERE c.deleted_at IS NULL
ORDER BY MAX(
  julianday(c.updated_at),
  COALESCE((SELECT MAX(julianday(updated_at)) FROM job_money m
    WHERE m.customer_id = c.id), 0)
) DESC""",
          variables: [Variable<DateTime>(today.toUtc())],
          readsFrom: {
            db.customers,
            db.customerUnits,
            db.jobs,
            db.jobItems,
            db.payments,
          },
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              CustomerSummary(
                customer: customerFromRow(db.customers.map(row.data)),
                jobCount: row.read<int>('job_count'),
                unitCount: row.read<int>('unit_count'),
                owedPiastres: row.read<int>('owed'),
                owedSince: _time(row.read<double?>('owed_since')),
                lastFinishedAt: _time(row.read<double?>('last_finished')),
                nextScheduledAt: _time(row.read<double?>('next_scheduled')),
                nextServiceOn: CalendarDate.tryParse(
                  row.read<String?>('next_service'),
                ),
              ),
          ],
        );
  }

  static DateTime? _time(double? julianDay) =>
      julianDay == null ? null : fromJulianDay(julianDay).toLocal();

  @override
  Stream<CustomerRecord?> watchCustomer(String id) {
    final db = _database;
    return watchTables(db, {db.customers, db.customerUnits, db.jobs}, () async {
      final row =
          await (db.select(db.customers)..where(
                (customer) =>
                    customer.id.equals(id) & customer.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (row == null) return null;
      final units =
          await (db.select(db.customerUnits)
                ..where(
                  (unit) =>
                      unit.customerId.equals(id) & unit.deletedAt.isNull(),
                )
                ..orderBy([(unit) => OrderingTerm(expression: unit.createdAt)]))
              .get();
      return CustomerRecord(
        customer: customerFromRow(row),
        units: units.map(unitFromRow).toList(),
        bookedInApp: await _hasAppBookings(id),
      );
    });
  }

  @override
  Future<Customer?> findByPhone(PhoneNumber phone) async {
    final row =
        await (_database.select(_database.customers)
              ..where(
                (customer) =>
                    customer.phone.equals(phone.e164) &
                    customer.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : customerFromRow(row);
  }

  @override
  Future<Result<Customer>> addCustomer(CustomerDraft draft) => _write(() async {
    final now = _now();
    final row = CustomerRow(
      id: _uuid.v4(),
      name: normalizeText(draft.name) ?? '',
      phone: draft.phone?.e164,
      areaId: draft.areaId,
      address: normalizeText(draft.address),
      notes: normalizeText(draft.notes),
      source: draft.source == CustomerSource.contacts ? 'contacts' : 'manual',
      createdAt: now,
      updatedAt: now,
    );
    await _database.into(_database.customers).insert(row);
    await _database.enqueue(SyncEntity.customers, row.id, now: now);
    return customerFromRow(row);
  });

  @override
  Future<Result<void>> updateCustomer(String id, CustomerDraft draft) =>
      _write(() async {
        final now = _now();
        final row = await _customerRow(id);
        await _database.put(
          _database.customers,
          row.copyWith(
            name: normalizeText(draft.name) ?? '',
            phone: Value(draft.phone?.e164),
            areaId: Value(draft.areaId),
            address: Value(normalizeText(draft.address)),
            notes: Value(normalizeText(draft.notes)),
            updatedAt: now,
          ),
        );
        await _database.enqueue(SyncEntity.customers, id, now: now);
      });

  @override
  Future<Result<void>> deleteCustomer(String id) => _write(() async {
    if (await _hasAppBookings(id)) {
      throw StateError('A customer booked through the app stays');
    }
    final db = _database;
    final now = _now();
    final row = await _customerRow(id);
    await db.put(
      db.customers,
      row.copyWith(deletedAt: Value(now), updatedAt: now),
    );
    await db.enqueue(SyncEntity.customers, id, now: now);
    final units =
        await (db.select(
              db.customerUnits,
            )..where(
              (unit) => unit.customerId.equals(id) & unit.deletedAt.isNull(),
            ))
            .get();
    for (final unit in units) {
      await db.put(
        db.customerUnits,
        unit.copyWith(deletedAt: Value(now), updatedAt: now),
      );
      await db.enqueue(SyncEntity.customerUnits, unit.id, now: now);
    }
    final jobs =
        await (db.select(
              db.jobs,
            )..where(
              (job) => job.customerId.equals(id) & job.deletedAt.isNull(),
            ))
            .get();
    for (final job in jobs) {
      await db.put(
        db.jobs,
        job.copyWith(deletedAt: Value(now), updatedAt: now),
      );
      await db.enqueue(SyncEntity.jobs, job.id, now: now);
    }
  });

  @override
  Future<Result<void>> addUnit(String customerId, CustomerUnitDraft draft) =>
      _write(() async {
        final now = _now();
        final id = _uuid.v4();
        await _database
            .into(_database.customerUnits)
            .insert(
              CustomerUnitRow(
                id: id,
                customerId: customerId,
                brand: normalizeText(draft.brand),
                capacityHp: draft.capacityHp,
                room: normalizeText(draft.room),
                installedYear: draft.installedYear,
                nextServiceOn: _date(draft.nextServiceOn),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _database.enqueue(SyncEntity.customerUnits, id, now: now);
      });

  @override
  Future<Result<void>> updateUnit(String id, CustomerUnitDraft draft) =>
      _write(() async {
        final now = _now();
        final row = await _unitRow(id);
        await _database.put(
          _database.customerUnits,
          row.copyWith(
            brand: Value(normalizeText(draft.brand)),
            capacityHp: Value(draft.capacityHp),
            room: Value(normalizeText(draft.room)),
            installedYear: Value(draft.installedYear),
            nextServiceOn: Value(_date(draft.nextServiceOn)),
            updatedAt: now,
          ),
        );
        await _database.enqueue(SyncEntity.customerUnits, id, now: now);
      });

  @override
  Future<Result<void>> deleteUnit(String id) => _write(() async {
    final now = _now();
    final row = await _unitRow(id);
    await _database.put(
      _database.customerUnits,
      row.copyWith(deletedAt: Value(now), updatedAt: now),
    );
    await _database.enqueue(SyncEntity.customerUnits, id, now: now);
  });

  DateTime _now() => _clock().toUtc();

  static String? _date(DateTime? day) =>
      day == null ? null : CalendarDate.format(day);

  Future<CustomerRow> _customerRow(String id) => (_database.select(
    _database.customers,
  )..where((customer) => customer.id.equals(id))).getSingle();

  Future<CustomerUnitRow> _unitRow(String id) => (_database.select(
    _database.customerUnits,
  )..where((unit) => unit.id.equals(id))).getSingle();

  /// Whether a live job came to this customer through the app; the server
  /// keeps such customers, so they can't be deleted here either.
  Future<bool> _hasAppBookings(String customerId) async {
    final job =
        await (_database.select(_database.jobs)
              ..where(
                (job) =>
                    job.customerId.equals(customerId) &
                    job.source.equals('platform') &
                    job.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return job != null;
  }

  /// Runs [action] in a transaction, then tells the sync about it.
  Future<Result<T>> _write<T>(Future<T> Function() action) async {
    try {
      final value = await _database.transaction(action);
      _changes.notify();
      return Ok(value);
    } on Object catch (error) {
      return Err(UnexpectedFailure(error));
    }
  }
}
