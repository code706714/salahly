import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/sync/sync_engine.dart';
import 'package:salahly/core/sync/sync_remote.dart';
import 'package:salahly/core/sync/sync_tables.dart';

import '../../helpers/fake_sync_remote.dart';

void main() {
  late AppDatabase db;
  late FakeSyncRemote remote;
  late Directory photoDir;
  late LocalPhotoStore photos;
  late SyncEngine engine;
  final now = DateTime.utc(2026, 10, 2, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    remote = FakeSyncRemote();
    photoDir = Directory.systemTemp.createTempSync('photos');
    photos = LocalPhotoStore(photoDir);
    engine = SyncEngine(
      database: db,
      remote: remote,
      photos: photos,
      clock: () => now,
    );
  });

  tearDown(() async {
    await db.close();
    if (photoDir.existsSync()) photoDir.deleteSync(recursive: true);
  });

  PullPage serverPage() {
    final json = File('test/fixtures/sync_pull_page.json').readAsStringSync();
    return PullPage.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  CustomersCompanion customer(String id, {String name = 'أ. كريم منصور'}) =>
      CustomersCompanion.insert(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
      );

  JobsCompanion job(String id, String customerId) => JobsCompanion.insert(
    id: id,
    customerId: customerId,
    tags: const ['cleaning'],
    scheduledAt: Value(DateTime.utc(2026, 10, 2, 10)),
    createdAt: now,
    updatedAt: now,
  );

  Future<void> saveLocally<T extends Table, R>(
    TableInfo<T, R> table,
    Insertable<R> row,
    String entity,
    String id,
  ) => db.transaction(() async {
    await db.into(table).insertOnConflictUpdate(row);
    await db.enqueue(entity, id, now: now);
  });

  Future<List<OutboxEntry>> outbox() => db.select(db.outbox).get();

  group('pull', () {
    test('stores every kind of row the server sends', () async {
      remote.pages.add(serverPage());

      await engine.run();

      final customer = await db.select(db.customers).getSingle();
      expect(customer.name, 'م. شريف عادل');
      expect(customer.areaId, 'heliopolis');
      expect(customer.createdAt, DateTime.utc(2026, 10, 2, 17, 6, 4, 187, 262));
      final unit = await db.select(db.customerUnits).getSingle();
      expect(unit.capacityHp, 2.25);
      expect(unit.installedYear, isNull);
      final job = await db.select(db.jobs).getSingle();
      expect(job.tags, ['cleaning', 'installation']);
      expect(job.status, 'confirmed');
      expect(job.scheduledAt, DateTime.utc(2026, 10, 2, 10));
      expect(job.durationMinutes, 60);
      final item = await db.select(db.jobItems).getSingle();
      expect(item.unitPricePiastres, 90000);
      final payment = await db.select(db.payments).getSingle();
      expect(payment.method, 'cash');
      expect(payment.receivedAt, DateTime.utc(2026, 10, 2, 13));
      final photo = await db.select(db.jobPhotos).getSingle();
      expect(photo.kind, 'before');
      expect(await outbox(), isEmpty);
    });

    test('clears local values the server cleared', () async {
      remote.pages.add(serverPage());
      await engine.run();
      final page = serverPage();
      final customer = page.rows.first;
      remote.pages.add(
        PullPage(
          rows: [
            PulledRow(
              entity: customer.entity,
              row: {...customer.row, 'phone': null, 'address': null},
            ),
          ],
          checkpoint: page.checkpoint,
          hasMore: false,
        ),
      );

      await engine.run();

      final stored = await db.select(db.customers).getSingle();
      expect(stored.phone, isNull);
      expect(stored.address, isNull);
    });

    test('resumes from the saved checkpoint', () async {
      remote.pages.add(serverPage());
      await engine.run();
      await engine.run();

      expect(remote.pulls, [
        null,
        {'txid': '1927', 'version': 12},
      ]);
      expect(
        jsonDecode((await db.readMeta(SyncEngine.checkpointKey))!),
        {'txid': '1927', 'version': 12},
      );
    });

    test('follows pages until the server has no more', () async {
      final page = serverPage();
      remote.pages
        ..add(
          PullPage(
            rows: page.rows.take(1).toList(),
            checkpoint: const {'txid': '1', 'version': 1},
            hasMore: true,
          ),
        )
        ..add(
          PullPage(
            rows: page.rows.skip(1).toList(),
            checkpoint: const {'txid': '2', 'version': 9},
            hasMore: false,
          ),
        );

      await engine.run();

      expect(remote.pulls, [
        null,
        {'txid': '1', 'version': 1},
      ]);
      expect(await db.select(db.jobPhotos).get(), hasLength(1));
    });

    test('never overwrites a row edited since the push', () async {
      const id = 'a0000000-0000-4000-8000-000000000001';
      remote
        ..pages.add(serverPage())
        ..duringPull = () => saveLocally(
          db.customers,
          customer(id, name: 'الاسم الجديد'),
          SyncEntity.customers,
          id,
        );

      await engine.run();

      expect((await db.select(db.customers).getSingle()).name, 'الاسم الجديد');
      expect(await outbox(), hasLength(1));
    });

    test('skips rows of kinds this version does not know', () async {
      remote.pages.add(
        const PullPage(
          rows: [
            PulledRow(entity: 'invoices', row: {'id': 'x'}),
          ],
          checkpoint: {'txid': '3', 'version': 4},
          hasMore: false,
        ),
      );

      await engine.run();

      expect(await db.readMeta(SyncEngine.checkpointKey), isNotNull);
    });
  });

  group('push', () {
    test('sends parents first, in the server format, then clears', () async {
      // Queued child first, as an offline edit order could be.
      await saveLocally(db.jobs, job('j1', 'c1'), SyncEntity.jobs, 'j1');
      await saveLocally(
        db.customers,
        customer('c1'),
        SyncEntity.customers,
        'c1',
      );

      await engine.run();

      final sent = remote.pushes.single;
      expect(sent.map((change) => change.entity), ['customers', 'jobs']);
      expect(sent.last.row, containsPair('tags', ['cleaning']));
      expect(sent.last.row, containsPair('customer_id', 'c1'));
      expect(
        sent.last.row,
        containsPair('scheduled_at', '2026-10-02T10:00:00.000Z'),
      );
      expect(await outbox(), isEmpty);
    });

    test('sends local times in UTC', () async {
      final local = DateTime(2026, 10, 2, 13);
      await saveLocally(
        db.jobs,
        job('j1', 'c1').copyWith(scheduledAt: Value(local)),
        SyncEntity.jobs,
        'j1',
      );

      await engine.run();

      expect(
        remote.pushes.single.single.row['scheduled_at'],
        local.toUtc().toIso8601String(),
      );
    });

    test(
      'keeps the entry of a row edited while its push was in flight',
      () async {
        await saveLocally(
          db.customers,
          customer('c1'),
          SyncEntity.customers,
          'c1',
        );
        var edited = false;
        remote.duringPush = () async {
          if (edited) return;
          edited = true;
          await saveLocally(
            db.customers,
            customer('c1', name: 'تعديل وقت الإرسال'),
            SyncEntity.customers,
            'c1',
          );
        };

        await engine.run();

        // The second push carried the edit and cleared it.
        expect(remote.pushes, hasLength(2));
        expect(remote.pushes.last.single.row['name'], 'تعديل وقت الإرسال');
        expect(await outbox(), isEmpty);
      },
    );

    test('puts back the server copy of a refused row', () async {
      await saveLocally(
        db.customers,
        customer('c1', name: 'x'),
        SyncEntity.customers,
        'c1',
      );
      final serverRow = {
        ...serverPage().rows.first.row,
        'id': 'c1',
        'name': 'نسخة السيرفر',
      };
      remote.pushReplies.add([
        SyncRejection(
          entity: 'customers',
          id: 'c1',
          code: 'new row violates check constraint',
          serverRow: serverRow,
        ),
      ]);

      await engine.run();

      expect((await db.select(db.customers).getSingle()).name, 'نسخة السيرفر');
      expect(await outbox(), isEmpty);
    });

    test('parks a refused new row until it is edited again', () async {
      await saveLocally(
        db.customers,
        customer('c1'),
        SyncEntity.customers,
        'c1',
      );
      remote.pushReplies.add([
        const SyncRejection(
          entity: 'customers',
          id: 'c1',
          code: 'limit_reached',
        ),
      ]);

      await engine.run();
      await engine.run();

      expect(remote.pushes, hasLength(1));
      expect((await outbox()).single.rejectedCode, 'limit_reached');
      expect(await db.select(db.customers).get(), hasLength(1));

      await saveLocally(
        db.customers,
        customer('c1'),
        SyncEntity.customers,
        'c1',
      );
      expect((await outbox()).single.rejectedCode, isNull);
      await engine.run();
      expect(remote.pushes, hasLength(2));
      expect(await outbox(), isEmpty);
    });

    test('splits large backlogs into server-sized batches', () async {
      await db.transaction(() async {
        for (var i = 0; i < SyncRemote.maxPushSize + 5; i++) {
          await saveLocally(
            db.customers,
            customer('c$i'),
            SyncEntity.customers,
            'c$i',
          );
        }
      });

      await engine.run();

      expect(remote.pushes.map((batch) => batch.length), [
        SyncRemote.maxPushSize,
        5,
      ]);
      expect(await outbox(), isEmpty);
    });

    test('keeps every entry when the server cannot be reached', () async {
      await saveLocally(
        db.customers,
        customer('c1'),
        SyncEntity.customers,
        'c1',
      );
      remote.failure = const SocketException('offline');

      await expectLater(engine.run(), throwsA(isA<SocketException>()));

      expect(await outbox(), hasLength(1));
    });
  });

  group('photos', () {
    const photoId = 'p1';
    const storagePath = 'user/p1.jpg';

    Future<void> takePhoto({bool withFile = true}) async {
      if (withFile) {
        final picked = File('${Directory.systemTemp.path}/picked.jpg')
          ..writeAsBytesSync([1, 2, 3]);
        await photos.keep(photoId, picked.path);
      }
      await db.transaction(() async {
        await db
            .into(db.jobPhotos)
            .insert(
              JobPhotosCompanion.insert(
                id: photoId,
                jobId: 'j1',
                kind: 'before',
                storagePath: storagePath,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.pendingUploads)
            .insert(
              PendingUploadsCompanion.insert(
                photoId: photoId,
                storagePath: storagePath,
                queuedAt: now,
              ),
            );
      });
    }

    test('uploads the file, then sends its row in the same sync', () async {
      await takePhoto();

      await engine.run();

      expect(remote.uploads, [storagePath]);
      expect(remote.pushes.single.single.entity, 'job_photos');
      expect(await db.select(db.pendingUploads).get(), isEmpty);
      expect(await outbox(), isEmpty);
    });

    test('keeps photos the server refuses today and syncs the rest', () async {
      await takePhoto();
      await saveLocally(
        db.customers,
        customer('c1'),
        SyncEntity.customers,
        'c1',
      );
      remote.uploadFailure = const UploadRefusedException();

      await engine.run();

      expect(await db.select(db.pendingUploads).get(), hasLength(1));
      expect(remote.pushes.single.single.entity, 'customers');
      expect(remote.pulls, hasLength(1));
    });

    test('drops a photo whose file is gone', () async {
      await takePhoto(withFile: false);

      await engine.run();

      expect(remote.uploads, isEmpty);
      expect(await db.select(db.jobPhotos).get(), isEmpty);
      expect(await db.select(db.pendingUploads).get(), isEmpty);
    });
  });

  test('a pulled row converts back to the same server row', () async {
    final page = serverPage();
    remote.pages.add(page);
    await engine.run();

    for (final table in syncTables(db)) {
      final pulled = page.rows.singleWhere((row) => row.entity == table.entity);
      final stored = await table.find(db, pulled.row['id'] as String);
      final sent = table.toServer(stored);
      for (final MapEntry(:key, :value) in pulled.row.entries) {
        final actual = sent[key];
        if (value is String && actual is String && key.endsWith('_at')) {
          expect(DateTime.parse(actual), DateTime.parse(value), reason: key);
        } else {
          expect(actual, value, reason: '${table.entity}.$key');
        }
      }
    }
  });
}
