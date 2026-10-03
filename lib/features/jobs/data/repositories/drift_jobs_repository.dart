import 'package:drift/drift.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/database/watch_tables.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_tables.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/customers/data/mappers/customer_mapper.dart';
import 'package:salahly/features/jobs/data/mappers/job_mapper.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:uuid/uuid.dart';

/// Jobs in the phone's database. Every write is queued for sync in the
/// same transaction.
class DriftJobsRepository implements JobsRepository {
  DriftJobsRepository({
    required this._database,
    required this._photos,
    required this._changes,
    required this._currentUserId,
    this._uuid = const Uuid(),
    this._clock = DateTime.now,
  });

  final AppDatabase _database;
  final LocalPhotoStore _photos;
  final LocalChanges _changes;
  final String? Function() _currentUserId;
  final Uuid _uuid;
  final DateTime Function() _clock;

  static const _open = "('unconfirmed', 'confirmed', 'started')";

  /// Every job column plus what lists need: the customer and the money.
  static const _summarySelect = '''
SELECT j.*,
  c.name AS customer_name, c.phone AS customer_phone,
  c.area_id AS customer_area_id, c.address AS customer_address,
  COALESCE(i.total, 0) AS total, COALESCE(i.count, 0) AS item_count,
  COALESCE(p.paid, 0) AS paid,
  (EXISTS (
    SELECT 1 FROM outbox o
    WHERE (o.entity = 'jobs' AND o.row_id = j.id)
      OR (o.entity = 'job_items'
        AND o.row_id IN (SELECT id FROM job_items WHERE job_id = j.id))
      OR (o.entity = 'payments'
        AND o.row_id IN (SELECT id FROM payments WHERE job_id = j.id))
      OR (o.entity = 'job_photos'
        AND o.row_id IN (SELECT id FROM job_photos WHERE job_id = j.id))
  ) OR EXISTS (
    SELECT 1 FROM pending_uploads u
    JOIN job_photos ph ON ph.id = u.photo_id
    WHERE ph.job_id = j.id
  )) AS unsynced
FROM jobs j
JOIN customers c ON c.id = j.customer_id
LEFT JOIN (
  SELECT job_id, SUM(unit_price_piastres * quantity) AS total, COUNT(*) AS count
  FROM job_items WHERE deleted_at IS NULL GROUP BY job_id
) i ON i.job_id = j.id
LEFT JOIN (
  SELECT job_id, SUM(amount_piastres) AS paid
  FROM payments WHERE deleted_at IS NULL GROUP BY job_id
) p ON p.job_id = j.id
WHERE j.deleted_at IS NULL''';

  Set<ResultSetImplementation<dynamic, dynamic>> get _summaryTables => {
    _database.jobs,
    _database.customers,
    _database.jobItems,
    _database.payments,
    _database.jobPhotos,
    _database.outbox,
    _database.pendingUploads,
  };

  Stream<List<JobSummary>> _watchSummaries(
    String filterAndOrder, [
    List<Variable<Object>> variables = const [],
  ]) {
    return _database
        .customSelect(
          '$_summarySelect $filterAndOrder',
          variables: variables,
          readsFrom: _summaryTables,
        )
        .watch()
        .map((rows) => rows.map(_summaryFromRow).toList());
  }

  JobSummary _summaryFromRow(QueryRow row) {
    final phone = row.read<String?>('customer_phone');
    return JobSummary(
      job: jobFromRow(_database.jobs.map(row.data)),
      customerName: row.read<String>('customer_name'),
      customerPhone: phone == null ? null : PhoneNumber.tryParse(phone),
      customerAreaId: row.read<String?>('customer_area_id'),
      customerAddress: row.read<String?>('customer_address'),
      totalPiastres: row.read<int>('total'),
      paidPiastres: row.read<int>('paid'),
      itemCount: row.read<int>('item_count'),
      isSynced: !row.read<bool>('unsynced'),
    );
  }

  @override
  Stream<List<JobSummary>> watchScheduled({
    required DateTime from,
    required DateTime to,
  }) => _watchSummaries(
    """
AND j.status <> 'cancelled'
AND julianday(j.scheduled_at) >= julianday(?)
AND julianday(j.scheduled_at) < julianday(?)
ORDER BY julianday(j.scheduled_at)""",
    [Variable<DateTime>(from.toUtc()), Variable<DateTime>(to.toUtc())],
  );

  @override
  Stream<List<JobSummary>> watchOpen() => _watchSummaries(
    '''
AND j.status IN $_open
ORDER BY j.scheduled_at IS NULL, julianday(j.scheduled_at), julianday(j.created_at)''',
  );

  @override
  Stream<List<JobSummary>> watchAwaitingPayment() => _watchSummaries('''
AND j.status = 'finished' AND COALESCE(i.total, 0) > COALESCE(p.paid, 0)
ORDER BY julianday(j.finished_at)''');

  @override
  Stream<List<JobSummary>> watchClosed({int limit = 100}) => _watchSummaries(
    """
AND (j.status IN ('paid', 'cancelled')
  OR (j.status = 'finished' AND COALESCE(i.total, 0) <= COALESCE(p.paid, 0)))
ORDER BY julianday(COALESCE(j.paid_at, j.cancelled_at, j.finished_at, j.updated_at)) DESC
LIMIT ?""",
    [Variable<int>(limit)],
  );

  @override
  Stream<List<JobSummary>> watchCustomerJobs(String customerId) =>
      _watchSummaries(
        '''
AND j.customer_id = ?
ORDER BY julianday(COALESCE(j.scheduled_at, j.created_at)) DESC''',
        [Variable<String>(customerId)],
      );

  @override
  Stream<bool> watchHasJobs() => _database
      .customSelect(
        'SELECT EXISTS (SELECT 1 FROM jobs WHERE deleted_at IS NULL) AS any',
        readsFrom: {_database.jobs},
      )
      .watchSingle()
      .map((row) => row.read<bool>('any'));

  @override
  Stream<JobDetails?> watchJob(String id) =>
      watchTables(_database, _summaryTables, () => _loadDetails(id));

  Future<JobDetails?> _loadDetails(String id) async {
    final db = _database;
    final row =
        await (db.select(db.jobs)
              ..where((job) => job.id.equals(id) & job.deletedAt.isNull()))
            .getSingleOrNull();
    if (row == null) return null;
    final customer =
        await (db.select(
              db.customers,
            )..where((customer) => customer.id.equals(row.customerId)))
            .getSingleOrNull();
    if (customer == null) return null;
    final items =
        await (db.select(db.jobItems)
              ..where((item) => item.jobId.equals(id) & item.deletedAt.isNull())
              ..orderBy([
                (item) => OrderingTerm(expression: item.sortOrder),
                (item) => OrderingTerm(expression: item.createdAt),
              ]))
            .get();
    final payments =
        await (db.select(db.payments)
              ..where(
                (payment) =>
                    payment.jobId.equals(id) & payment.deletedAt.isNull(),
              )
              ..orderBy([
                (payment) => OrderingTerm(expression: payment.receivedAt),
              ]))
            .get();
    final photos =
        await (db.select(db.jobPhotos)
              ..where(
                (photo) => photo.jobId.equals(id) & photo.deletedAt.isNull(),
              )
              ..orderBy([(photo) => OrderingTerm(expression: photo.createdAt)]))
            .get();
    final unsynced = await db
        .customSelect(
          '$_summarySelect AND j.id = ?',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return JobDetails(
      job: jobFromRow(row),
      customer: customerFromRow(customer),
      items: items.map(itemFromRow).toList(),
      payments: payments.map(paymentFromRow).toList(),
      photos: [for (final photo in photos) photoFromRow(photo, _photos)],
      isSynced: !(unsynced?.read<bool>('unsynced') ?? false),
    );
  }

  @override
  Stream<MonthIncome> watchMonthIncome(DateTime month) {
    final from = DateTime(month.year, month.month);
    final to = DateTime(month.year, month.month + 1);
    return _database
        .customSelect(
          """
SELECT COUNT(*) AS jobs, COALESCE(SUM(total), 0) AS total,
  COALESCE(SUM(MIN(paid, total)), 0) AS collected
FROM ($_summarySelect
  AND j.status IN ('finished', 'paid')
  AND julianday(j.finished_at) >= julianday(?)
  AND julianday(j.finished_at) < julianday(?))""",
          variables: [
            Variable<DateTime>(from.toUtc()),
            Variable<DateTime>(to.toUtc()),
          ],
          readsFrom: _summaryTables,
        )
        .watchSingle()
        .map(
          (row) => MonthIncome(
            jobCount: row.read<int>('jobs'),
            totalPiastres: row.read<int>('total'),
            collectedPiastres: row.read<int>('collected'),
          ),
        );
  }

  @override
  Future<List<ItemSuggestion>> itemSuggestions() async {
    final rows = await _database.customSelect('''
SELECT title, unit_price_piastres FROM (
  SELECT title, unit_price_piastres, COUNT(*) OVER (PARTITION BY title) AS uses,
    ROW_NUMBER() OVER (PARTITION BY title ORDER BY julianday(created_at) DESC) AS recency
  FROM job_items WHERE deleted_at IS NULL
) WHERE recency = 1 ORDER BY uses DESC, title LIMIT 30''').get();
    return [
      for (final row in rows)
        ItemSuggestion(
          title: row.read<String>('title'),
          unitPricePiastres: row.read<int>('unit_price_piastres'),
        ),
    ];
  }

  @override
  Future<Result<String>> createJob(JobDraft draft) => _write(() async {
    final now = _now();
    final id = _uuid.v4();
    await _database
        .into(_database.jobs)
        .insert(
          JobsCompanion.insert(
            id: id,
            customerId: draft.customerId,
            tags: _tagsToWire(draft.tags),
            description: Value(normalizeText(draft.description)),
            scheduledAt: Value(draft.scheduledAt?.toUtc()),
            durationMinutes: Value(draft.durationMinutes),
            address: Value(normalizeText(draft.address)),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _database.enqueue(SyncEntity.jobs, id, now: now);
    return id;
  });

  @override
  Future<Result<void>> reschedule(
    String id, {
    required DateTime? scheduledAt,
    required int durationMinutes,
  }) => _updateJob(
    id,
    (row, now) => row.copyWith(
      scheduledAt: Value(scheduledAt?.toUtc()),
      durationMinutes: durationMinutes,
    ),
  );

  @override
  Future<Result<Job>> advance(String id) => _write(() async {
    final row = await _jobRow(id);
    final previous = jobFromRow(row);
    final next = previous.status.next;
    if (next == null) return previous;
    final now = _now();
    var updated = row.copyWith(status: next.name, updatedAt: now);
    updated = switch (next) {
      JobStatus.confirmed => updated.copyWith(
        confirmedAt: Value(now),
        // Confirming the visit means the customer agreed to the price.
        quoteStatus: row.quoteStatus == QuoteStatus.sent.name
            ? QuoteStatus.accepted.name
            : null,
      ),
      JobStatus.started => updated.copyWith(startedAt: Value(now)),
      JobStatus.finished => await _paidIfSettled(
        id,
        updated.copyWith(finishedAt: Value(now)),
        now,
      ),
      _ => updated,
    };
    await _saveJob(updated, now);
    return previous;
  });

  /// [row] marked paid when its lines are covered by what was received.
  Future<JobRow> _paidIfSettled(String jobId, JobRow row, DateTime now) async {
    final money = await _database
        .customSelect(
          '$_summarySelect AND j.id = ?',
          variables: [Variable<String>(jobId)],
        )
        .getSingle();
    final total = money.read<int>('total');
    final paid = money.read<int>('paid');
    if (total == 0 || paid < total) return row;
    return row.copyWith(status: JobStatus.paid.name, paidAt: Value(now));
  }

  @override
  Future<Result<void>> restore(Job previous) => _updateJob(
    previous.id,
    (row, now) => jobOntoRow(row, previous, now: now),
  );

  @override
  Future<Result<Job>> cancel(String id) => _write(() async {
    final row = await _jobRow(id);
    final now = _now();
    await _saveJob(
      row.copyWith(
        status: JobStatus.cancelled.name,
        cancelledAt: Value(now),
        updatedAt: now,
      ),
      now,
    );
    return jobFromRow(row);
  });

  @override
  Future<Result<void>> deleteJob(String id) =>
      _updateJob(id, (row, now) => row.copyWith(deletedAt: Value(now)));

  @override
  Future<Result<void>> saveQuote(
    String jobId, {
    required List<JobItemDraft> items,
    required int validDays,
    required QuoteStatus status,
  }) => _write(() async {
    final db = _database;
    final now = _now();
    final existing =
        await (db.select(
              db.jobItems,
            )..where(
              (item) => item.jobId.equals(jobId) & item.deletedAt.isNull(),
            ))
            .get();
    final keptIds = {for (final item in items) item.id};
    for (final old in existing.where((item) => !keptIds.contains(item.id))) {
      await db.put(
        db.jobItems,
        old.copyWith(deletedAt: Value(now), updatedAt: now),
      );
      await db.enqueue(SyncEntity.jobItems, old.id, now: now);
    }
    final byId = {for (final item in existing) item.id: item};
    for (final (index, item) in items.indexed) {
      final title = normalizeText(item.title) ?? '';
      final old = byId[item.id];
      if (old != null &&
          old.title == title &&
          old.unitPricePiastres == item.unitPricePiastres &&
          old.quantity == item.quantity &&
          old.sortOrder == index) {
        continue;
      }
      final id = old?.id ?? _uuid.v4();
      await db.put(
        db.jobItems,
        JobItemRow(
          id: id,
          jobId: jobId,
          title: title,
          unitPricePiastres: item.unitPricePiastres,
          quantity: item.quantity,
          sortOrder: index,
          createdAt: old?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      await db.enqueue(SyncEntity.jobItems, id, now: now);
    }
    final row = await _jobRow(jobId);
    await _saveJob(
      row.copyWith(
        quoteStatus: status.name,
        quoteValidDays: validDays,
        quoteSentAt: status == QuoteStatus.sent
            ? Value(now)
            : Value(row.quoteSentAt),
        updatedAt: now,
      ),
      now,
    );
  });

  @override
  Future<Result<int>> issueInvoice(String jobId) => _write(() async {
    final row = await _jobRow(jobId);
    if (row.invoiceNumber case final number?) return number;
    final last = await _database
        .customSelect('SELECT MAX(invoice_number) AS last FROM jobs')
        .getSingle();
    final number = (last.read<int?>('last') ?? 0) + 1;
    final now = _now();
    await _saveJob(
      row.copyWith(invoiceNumber: Value(number), updatedAt: now),
      now,
    );
    return number;
  });

  @override
  Future<Result<void>> recordPayment(
    String jobId, {
    required int amountPiastres,
    required PaymentMethod method,
  }) => _write(() async {
    final now = _now();
    final id = _uuid.v4();
    await _database
        .into(_database.payments)
        .insert(
          PaymentsCompanion.insert(
            id: id,
            jobId: jobId,
            amountPiastres: amountPiastres,
            method: paymentMethodToWire(method),
            receivedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _database.enqueue(SyncEntity.payments, id, now: now);
    final row = await _jobRow(jobId);
    if (row.status == JobStatus.finished.name) {
      final settled = await _paidIfSettled(jobId, row, now);
      if (settled != row) await _saveJob(settled.copyWith(updatedAt: now), now);
    }
  });

  @override
  Future<Result<void>> setPaymentPromise(String jobId, DateTime? day) =>
      _updateJob(
        jobId,
        (row, now) => row.copyWith(
          paymentPromisedOn: Value(
            day == null ? null : CalendarDate.format(day),
          ),
        ),
      );

  @override
  Future<Result<void>> addPhoto(
    String jobId, {
    required PhotoKind kind,
    required String pickedPath,
  }) => _write(() async {
    final userId = _currentUserId();
    if (userId == null) throw StateError('No one is signed in');
    final now = _now();
    final id = _uuid.v4();
    final storagePath = '$userId/$id.jpg';
    await _photos.keep(id, pickedPath);
    await _database
        .into(_database.jobPhotos)
        .insert(
          JobPhotosCompanion.insert(
            id: id,
            jobId: jobId,
            kind: kind.name,
            storagePath: storagePath,
            createdAt: now,
            updatedAt: now,
          ),
        );
    // The row is queued once the file is uploaded; see SyncEngine.
    await _database
        .into(_database.pendingUploads)
        .insert(
          PendingUploadsCompanion.insert(
            photoId: id,
            storagePath: storagePath,
            queuedAt: now,
          ),
        );
  });

  @override
  Future<Result<void>> deletePhoto(String photoId) => _write(() async {
    final db = _database;
    final pending = await (db.delete(
      db.pendingUploads,
    )..where((upload) => upload.photoId.equals(photoId))).go();
    if (pending > 0) {
      // Never uploaded: nothing to tell the server.
      await (db.delete(
        db.jobPhotos,
      )..where((photo) => photo.id.equals(photoId))).go();
    } else {
      final row = await (db.select(
        db.jobPhotos,
      )..where((photo) => photo.id.equals(photoId))).getSingle();
      final now = _now();
      await db.put(
        db.jobPhotos,
        row.copyWith(deletedAt: Value(now), updatedAt: now),
      );
      await db.enqueue(SyncEntity.jobPhotos, photoId, now: now);
    }
    final file = _photos.fileFor(photoId);
    if (file.existsSync()) await file.delete();
  });

  DateTime _now() => _clock().toUtc();

  List<String> _tagsToWire(List<JobTag> tags) =>
      {for (final tag in tags) jobTagToWire(tag)}.toList()..sort();

  Future<JobRow> _jobRow(String id) => (_database.select(
    _database.jobs,
  )..where((job) => job.id.equals(id))).getSingle();

  Future<void> _saveJob(JobRow row, DateTime now) async {
    await _database.put(_database.jobs, row);
    await _database.enqueue(SyncEntity.jobs, row.id, now: now);
  }

  Future<Result<void>> _updateJob(
    String id,
    JobRow Function(JobRow row, DateTime now) change,
  ) => _write(() async {
    final now = _now();
    final row = await _jobRow(id);
    await _saveJob(change(row, now).copyWith(updatedAt: now), now);
  });

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
