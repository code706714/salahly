import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/database/local_user_data.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/core/sync/sync_tables.dart';

void main() {
  late AppDatabase db;
  late Directory photoDir;
  late LocalPhotoStore photos;
  late Directory sharedDir;
  late LocalUserData userData;
  final now = DateTime.utc(2026, 10, 2);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    photoDir = Directory('${Directory.systemTemp.createTempSync().path}/p');
    photos = LocalPhotoStore(photoDir);
    sharedDir = Directory('${photoDir.parent.path}/shared');
    userData = LocalUserData(db, photos, SharedFiles(sharedDir));
  });

  tearDown(() => db.close());

  Future<void> addRecords() async {
    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            id: 'c1',
            name: 'أ. كريم منصور',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.enqueue(SyncEntity.customers, 'c1', now: now);
    final picked = File('${Directory.systemTemp.path}/x.jpg')
      ..writeAsBytesSync([1]);
    await photos.keep('p1', picked.path);
    (await SharedFiles(
      sharedDir,
    ).file('invoice-0001.pdf')).writeAsBytesSync([1]);
  }

  test("keeps the same user's records across launches", () async {
    await userData.claimFor('u1');
    await addRecords();

    await userData.claimFor('u1');

    expect(await db.select(db.customers).get(), hasLength(1));
    expect(photos.fileFor('p1').existsSync(), isTrue);
  });

  test("deletes another user's records before handing over", () async {
    await userData.claimFor('u1');
    await addRecords();

    await userData.claimFor('u2');

    expect(await db.select(db.customers).get(), isEmpty);
    expect(await db.select(db.outbox).get(), isEmpty);
    expect(photos.fileFor('p1').existsSync(), isFalse);
    expect(sharedDir.existsSync(), isFalse);
    expect(await db.readMeta(LocalUserData.ownerKey), 'u2');
  });

  test('clear deletes everything, including whose data it was', () async {
    await userData.claimFor('u1');
    await addRecords();

    await userData.clear();

    expect(await db.select(db.customers).get(), isEmpty);
    expect(await db.readMeta(LocalUserData.ownerKey), isNull);
    expect(photoDir.existsSync(), isFalse);
    expect(sharedDir.existsSync(), isFalse);
  });
}
