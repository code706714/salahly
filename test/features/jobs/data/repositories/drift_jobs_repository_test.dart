import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_tables.dart';
import 'package:salahly/features/jobs/data/repositories/drift_jobs_repository.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

void main() {
  late AppDatabase db;
  late Directory photoDir;
  late LocalPhotoStore photos;
  late LocalChanges changes;
  late int notified;
  late DateTime now;
  late DriftJobsRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    photoDir = Directory.systemTemp.createTempSync('job_photos');
    photos = LocalPhotoStore(photoDir);
    changes = LocalChanges();
    notified = 0;
    changes.stream.listen((_) => notified++);
    now = DateTime(2026, 10, 2, 9);
    repository = DriftJobsRepository(
      database: db,
      photos: photos,
      changes: changes,
      currentUserId: () => 'user-1',
      clock: () => now,
    );
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'c1',
            name: 'م. شريف عادل',
            phone: const Value('+201002345678'),
            createdAt: now.toUtc(),
            updatedAt: now.toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
    if (photoDir.existsSync()) photoDir.deleteSync(recursive: true);
  });

  T ok<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
  };

  Future<String> newJob({
    DateTime? scheduledAt,
    List<JobTag> tags = const [JobTag.installation],
  }) async => ok(
    await repository.createJob(
      JobDraft(customerId: 'c1', tags: tags, scheduledAt: scheduledAt),
    ),
  );

  Future<void> price(String jobId, List<JobItemDraft> items) async => ok(
    await repository.saveQuote(
      jobId,
      items: items,
      validDays: 3,
      status: QuoteStatus.draft,
    ),
  );

  Future<List<OutboxEntry>> outbox() => db.select(db.outbox).get();

  Future<void> markSynced() => db.delete(db.outbox).go();

  group('createJob', () {
    test('saves the job in UTC and queues it for sync', () async {
      final at = DateTime(2026, 10, 2, 13);
      final id = await newJob(
        scheduledAt: at,
        tags: const [JobTag.notCooling, JobTag.cleaning, JobTag.cleaning],
      );

      final row = await db.select(db.jobs).getSingle();
      expect(row.id, id);
      expect(row.tags, ['cleaning', 'not_cooling']);
      expect(row.scheduledAt!.isUtc, isTrue);
      expect(row.scheduledAt, at.toUtc());
      expect(row.status, 'unconfirmed');
      expect((await outbox()).single.rowId, id);
      expect(notified, 1);
    });
  });

  group('watchScheduled', () {
    test("lists the day's jobs with their customer and money", () async {
      final today = DateTime(2026, 10, 2);
      final job = await newJob(scheduledAt: DateTime(2026, 10, 2, 13));
      await newJob(scheduledAt: DateTime(2026, 10, 3, 10));
      final cancelled = await newJob(scheduledAt: DateTime(2026, 10, 2, 16));
      ok(await repository.cancel(cancelled));
      await price(job, const [
        JobItemDraft(title: 'تركيب', unitPricePiastres: 90000),
        JobItemDraft(title: 'ماسورة', unitPricePiastres: 10000, quantity: 4),
      ]);
      ok(
        await repository.recordPayment(
          job,
          amountPiastres: 50000,
          method: PaymentMethod.cash,
        ),
      );

      final jobs = await repository
          .watchScheduled(
            from: today,
            to: today.add(const Duration(days: 1)),
          )
          .first;

      final summary = jobs.single;
      expect(summary.job.id, job);
      expect(summary.customerName, 'م. شريف عادل');
      expect(summary.customerPhone!.local, '0100 234 5678');
      expect(summary.totalPiastres, 130000);
      expect(summary.paidPiastres, 50000);
      expect(summary.balancePiastres, 80000);
      expect(summary.itemCount, 2);
      expect(summary.isSynced, isFalse);
    });

    test('marks a job synced once nothing of it is waiting', () async {
      await newJob(scheduledAt: DateTime(2026, 10, 2, 13));
      await markSynced();

      final jobs = await repository
          .watchScheduled(
            from: DateTime(2026, 10, 2),
            to: DateTime(2026, 10, 3),
          )
          .first;

      expect(jobs.single.isSynced, isTrue);
    });

    test('compares server times with microseconds correctly', () async {
      await db
          .into(db.jobs)
          .insert(
            JobRow.fromJson(
              {
                'id': 'pulled',
                'customer_id': 'c1',
                'tags': <String>[],
                'scheduled_at': '2026-10-02T23:59:59.999999+00:00',
                'duration_minutes': 60,
                'status': 'confirmed',
                'quote_status': 'none',
                'quote_valid_days': 3,
                'source': 'manual',
                'created_at': '2026-10-01T10:00:00.123456+00:00',
                'updated_at': '2026-10-01T10:00:00.123456+00:00',
              },
              serializer: const SyncSerializer(),
            ),
          );

      final inside = await repository
          .watchScheduled(
            from: DateTime.utc(2026, 10, 2, 23, 59, 59, 999),
            to: DateTime.utc(2026, 10, 3),
          )
          .first;
      final after = await repository
          .watchScheduled(
            from: DateTime.utc(2026, 10, 3),
            to: DateTime.utc(2026, 10, 4),
          )
          .first;

      expect(inside, hasLength(1));
      expect(after, isEmpty);
    });

    test('updates when a job changes', () async {
      final job = await newJob(scheduledAt: DateTime(2026, 10, 2, 13));
      final stream = repository.watchScheduled(
        from: DateTime(2026, 10, 2),
        to: DateTime(2026, 10, 3),
      );

      final expectation = expectLater(
        stream.map((jobs) => jobs.single.job.status),
        emitsInOrder([JobStatus.unconfirmed, JobStatus.confirmed]),
      );
      await pumpEventQueue();
      ok(await repository.advance(job));
      await expectation;
    });
  });

  group('advance', () {
    test('walks the job through its steps, stamping each', () async {
      final id = await newJob();

      for (final status in [
        JobStatus.confirmed,
        JobStatus.started,
        JobStatus.finished,
      ]) {
        now = now.add(const Duration(hours: 1));
        ok(await repository.advance(id));
        final job = (await repository.watchJob(id).first)!.job;
        expect(job.status, status);
      }
      final job = (await repository.watchJob(id).first)!.job;
      expect(job.confirmedAt, DateTime(2026, 10, 2, 10));
      expect(job.startedAt, DateTime(2026, 10, 2, 11));
      expect(job.finishedAt, DateTime(2026, 10, 2, 12));
    });

    test('takes confirming a visit as accepting the sent quote', () async {
      final id = await newJob();
      ok(
        await repository.saveQuote(
          id,
          items: const [JobItemDraft(title: 'تنظيف', unitPricePiastres: 30000)],
          validDays: 3,
          status: QuoteStatus.sent,
        ),
      );

      ok(await repository.advance(id));

      final job = (await repository.watchJob(id).first)!.job;
      expect(job.quoteStatus, QuoteStatus.accepted);
    });

    test('marks a job paid when it finishes already paid for', () async {
      final id = await newJob();
      await price(id, const [
        JobItemDraft(title: 'تنظيف', unitPricePiastres: 30000),
      ]);
      ok(await repository.advance(id));
      ok(await repository.advance(id));
      ok(
        await repository.recordPayment(
          id,
          amountPiastres: 30000,
          method: PaymentMethod.instapay,
        ),
      );

      ok(await repository.advance(id));

      final job = (await repository.watchJob(id).first)!.job;
      expect(job.status, JobStatus.paid);
      expect(job.paidAt, isNotNull);
    });

    test('can be undone with restore', () async {
      final id = await newJob();
      final before = (await repository.watchJob(id).first)!.job;

      final previous = ok(await repository.advance(id));
      ok(await repository.restore(previous));

      final job = (await repository.watchJob(id).first)!.job;
      expect(job.status, JobStatus.unconfirmed);
      expect(job.confirmedAt, isNull);
      expect(previous, before);
    });

    test('does nothing past the last step', () async {
      final id = await newJob();
      ok(await repository.cancel(id));
      await markSynced();

      ok(await repository.advance(id));

      expect(await outbox(), isEmpty);
    });
  });

  group('saveQuote', () {
    test('replaces the lines and only queues what changed', () async {
      final id = await newJob();
      await price(id, const [
        JobItemDraft(title: 'تركيب', unitPricePiastres: 90000),
        JobItemDraft(title: 'حامل', unitPricePiastres: 15000),
      ]);
      final saved = (await repository.watchJob(id).first)!.items;
      await markSynced();

      await price(id, [
        JobItemDraft(
          id: saved.first.id,
          title: saved.first.title,
          unitPricePiastres: saved.first.unitPricePiastres,
        ),
        const JobItemDraft(
          title: '  ماسورة   نحاس ',
          unitPricePiastres: 10000,
          quantity: 4,
        ),
      ]);

      final details = (await repository.watchJob(id).first)!;
      expect(details.items.map((item) => item.title), ['تركيب', 'ماسورة نحاس']);
      expect(details.totalPiastres, 130000);
      final queued = {
        for (final entry in await outbox()) (entry.entity, entry.rowId),
      };
      expect(queued, {
        (SyncEntity.jobItems, saved.last.id),
        (SyncEntity.jobItems, details.items.last.id),
        (SyncEntity.jobs, id),
      });
    });

    test('records when the quote was sent', () async {
      final id = await newJob();

      ok(
        await repository.saveQuote(
          id,
          items: const [JobItemDraft(title: 'تنظيف', unitPricePiastres: 30000)],
          validDays: 5,
          status: QuoteStatus.sent,
        ),
      );

      final job = (await repository.watchJob(id).first)!.job;
      expect(job.quoteStatus, QuoteStatus.sent);
      expect(job.quoteSentAt, now);
      expect(job.quoteValidDays, 5);
    });
  });

  group('payments', () {
    Future<String> finishedJob(int pricePiastres) async {
      final id = await newJob();
      await price(id, [
        JobItemDraft(title: 'شغل', unitPricePiastres: pricePiastres),
      ]);
      for (var i = 0; i < 3; i++) {
        ok(await repository.advance(id));
      }
      return id;
    }

    test('a partial payment leaves the job awaiting the rest', () async {
      final id = await finishedJob(170000);

      ok(
        await repository.recordPayment(
          id,
          amountPiastres: 50000,
          method: PaymentMethod.cash,
        ),
      );

      final awaiting = await repository.watchAwaitingPayment().first;
      expect(awaiting.single.job.id, id);
      expect(awaiting.single.balancePiastres, 120000);
      expect(awaiting.single.awaitsPayment, isTrue);
    });

    test('the last payment marks the job paid', () async {
      final id = await finishedJob(65000);

      ok(
        await repository.recordPayment(
          id,
          amountPiastres: 65000,
          method: PaymentMethod.vodafoneCash,
        ),
      );

      expect(await repository.watchAwaitingPayment().first, isEmpty);
      final details = (await repository.watchJob(id).first)!;
      expect(details.job.status, JobStatus.paid);
      expect(details.payments.single.method, PaymentMethod.vodafoneCash);
      expect(
        (await db.select(db.payments).getSingle()).method,
        'vodafone_cash',
      );
      expect((await repository.watchClosed().first).single.job.id, id);
    });

    test('remembers when the customer promised to pay', () async {
      final id = await finishedJob(60000);

      ok(await repository.setPaymentPromise(id, DateTime(2026, 10, 4)));

      final row = await db.select(db.jobs).getSingle();
      expect(row.paymentPromisedOn, '2026-10-04');
      final job = (await repository.watchJob(id).first)!.job;
      expect(job.paymentPromisedOn, DateTime(2026, 10, 4));
    });

    test("sums a month's finished jobs and what was collected", () async {
      final paid = await finishedJob(65000);
      ok(
        await repository.recordPayment(
          paid,
          amountPiastres: 65000,
          method: PaymentMethod.cash,
        ),
      );
      final partly = await finishedJob(170000);
      ok(
        await repository.recordPayment(
          partly,
          amountPiastres: 50000,
          method: PaymentMethod.cash,
        ),
      );
      await newJob();

      final october = await repository
          .watchMonthIncome(DateTime(2026, 10))
          .first;
      final september = await repository
          .watchMonthIncome(DateTime(2026, 9))
          .first;

      expect(
        october,
        const MonthIncome(
          jobCount: 2,
          totalPiastres: 235000,
          collectedPiastres: 115000,
        ),
      );
      expect(october.outstandingPiastres, 120000);
      expect(september, MonthIncome.empty);
    });
  });

  group('issueInvoice', () {
    test('numbers invoices in order and keeps a number once given', () async {
      final first = await newJob();
      final second = await newJob();

      expect(ok(await repository.issueInvoice(first)), 1);
      expect(ok(await repository.issueInvoice(second)), 2);
      expect(ok(await repository.issueInvoice(first)), 1);
    });
  });

  group('photos', () {
    String pickedPhoto() {
      final file = File(
        '${Directory.systemTemp.path}/picked-${now.hashCode}.jpg',
      )..writeAsBytesSync([1, 2, 3]);
      return file.path;
    }

    test('keeps the file and waits to upload before syncing the row', () async {
      final id = await newJob();
      await markSynced();

      ok(
        await repository.addPhoto(
          id,
          kind: PhotoKind.before,
          pickedPath: pickedPhoto(),
        ),
      );

      final photo = (await repository.watchJob(id).first)!.photos.single;
      expect(photo.kind, PhotoKind.before);
      expect(photo.storagePath, 'user-1/${photo.id}.jpg');
      expect(File(photo.localPath!).existsSync(), isTrue);
      expect(await outbox(), isEmpty);
      expect(
        (await db.select(db.pendingUploads).getSingle()).storagePath,
        photo.storagePath,
      );
    });

    test('deleting a photo not uploaded yet forgets it entirely', () async {
      final id = await newJob();
      ok(
        await repository.addPhoto(
          id,
          kind: PhotoKind.after,
          pickedPath: pickedPhoto(),
        ),
      );
      final photo = (await repository.watchJob(id).first)!.photos.single;
      await markSynced();

      ok(await repository.deletePhoto(photo.id));

      expect(await db.select(db.jobPhotos).get(), isEmpty);
      expect(await db.select(db.pendingUploads).get(), isEmpty);
      expect(await outbox(), isEmpty);
      expect(File(photo.localPath!).existsSync(), isFalse);
    });

    test('deleting an uploaded photo tells the server', () async {
      final id = await newJob();
      ok(
        await repository.addPhoto(
          id,
          kind: PhotoKind.after,
          pickedPath: pickedPhoto(),
        ),
      );
      final photo = (await repository.watchJob(id).first)!.photos.single;
      await db.delete(db.pendingUploads).go();
      await markSynced();

      ok(await repository.deletePhoto(photo.id));

      expect((await repository.watchJob(id).first)!.photos, isEmpty);
      expect((await outbox()).single.rowId, photo.id);
    });
  });

  test('suggests lines used before, most used first, latest price', () async {
    final first = await newJob();
    await price(first, const [
      JobItemDraft(title: 'ماسورة نحاس', unitPricePiastres: 9000),
      JobItemDraft(title: 'حامل', unitPricePiastres: 15000),
    ]);
    now = now.add(const Duration(days: 1));
    final second = await newJob();
    await price(second, const [
      JobItemDraft(title: 'ماسورة نحاس', unitPricePiastres: 10000),
    ]);

    final suggestions = await repository.itemSuggestions();

    expect(suggestions, const [
      ItemSuggestion(title: 'ماسورة نحاس', unitPricePiastres: 10000),
      ItemSuggestion(title: 'حامل', unitPricePiastres: 15000),
    ]);
  });

  test('deleted jobs disappear from every list', () async {
    final id = await newJob(scheduledAt: DateTime(2026, 10, 2, 13));

    ok(await repository.deleteJob(id));

    expect(await repository.watchOpen().first, isEmpty);
    expect(await repository.watchJob(id).first, isNull);
    expect(await repository.watchHasJobs().first, isFalse);
    expect((await outbox()).single.rowId, id);
  });
}
