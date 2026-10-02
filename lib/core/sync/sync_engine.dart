import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/sync/sync_remote.dart';
import 'package:salahly/core/sync/sync_tables.dart';

/// Moves changes between the phone's database and the server.
///
/// A run uploads waiting photos, pushes local edits parents first, then
/// pulls whatever changed on the server since the last checkpoint. Errors
/// reaching the server propagate and the caller retries later.
///
/// A local edit is never lost: its outbox entry is only cleared once the
/// server accepted that exact revision, and pulled rows never overwrite a
/// row that still has an entry.
class SyncEngine {
  SyncEngine({
    required this._database,
    required this._remote,
    required this._photos,
    this._clock = DateTime.now,
  });

  static const checkpointKey = 'sync.checkpoint';

  final AppDatabase _database;
  final SyncRemote _remote;
  final LocalPhotoStore _photos;
  final DateTime Function() _clock;

  late final List<SyncTable<Object?>> _tables = syncTables(_database);
  late final Map<String, SyncTable<Object?>> _tableByEntity = {
    for (final table in _tables) table.entity: table,
  };

  Future<void> run() async {
    await _uploadPhotos();
    await _push();
    await _pull();
  }

  Future<void> _uploadPhotos() async {
    final uploads = _database.pendingUploads;
    final pending = await (_database.select(
      uploads,
    )..orderBy([(upload) => OrderingTerm(expression: upload.queuedAt)])).get();
    for (final upload in pending) {
      final file = _photos.fileFor(upload.photoId);
      if (!file.existsSync()) {
        // The file is gone, so this photo can never reach the server.
        await _database.transaction(() async {
          await _deleteUpload(upload.photoId);
          await (_database.delete(
            _database.jobPhotos,
          )..where((photo) => photo.id.equals(upload.photoId))).go();
        });
        continue;
      }
      try {
        await _remote.uploadPhoto(
          storagePath: upload.storagePath,
          localPath: file.path,
        );
      } on UploadRefusedException {
        // The server's daily limit; the rest wait for a later sync.
        return;
      }
      await _database.transaction(() async {
        await _deleteUpload(upload.photoId);
        await _database.enqueue(
          SyncEntity.jobPhotos,
          upload.photoId,
          now: _clock(),
        );
      });
    }
  }

  Future<void> _deleteUpload(String photoId) => (_database.delete(
    _database.pendingUploads,
  )..where((upload) => upload.photoId.equals(photoId))).go();

  Future<void> _push() async {
    while (true) {
      final batch = await _nextBatch();
      if (batch.isEmpty) return;

      final changes = <SyncChange>[];
      for (final entry in batch) {
        final table = _tableByEntity[entry.entity];
        final row = await table?.find(_database, entry.rowId);
        if (table == null || row == null) {
          // Nothing left to send for this entry.
          await _clear(entry);
          continue;
        }
        changes.add(
          SyncChange(
            entity: entry.entity,
            id: entry.rowId,
            row: table.toServer(row),
          ),
        );
      }
      if (changes.isEmpty) continue;

      final rejections = {
        for (final rejection in await _remote.push(changes))
          (rejection.entity, rejection.id): rejection,
      };
      await _database.transaction(() async {
        for (final entry in batch) {
          final rejection = rejections[(entry.entity, entry.rowId)];
          if (rejection == null) {
            await _clear(entry);
          } else {
            await _reject(entry, rejection);
          }
        }
      });
    }
  }

  /// The next entries to push: parents before children, oldest first.
  Future<List<OutboxEntry>> _nextBatch() async {
    final entries = await (_database.select(
      _database.outbox,
    )..where((entry) => entry.rejectedCode.isNull())).get();
    final rank = {
      for (final (index, table) in _tables.indexed) table.entity: index,
    };
    entries.sort(
      (a, b) =>
          switch ((rank[a.entity] ?? -1).compareTo(rank[b.entity] ?? -1)) {
            0 => a.queuedAt.compareTo(b.queuedAt),
            final order => order,
          },
    );
    return entries.take(SyncRemote.maxPushSize).toList();
  }

  /// Removes [entry] unless the row was edited again since it was read.
  Future<bool> _clear(OutboxEntry entry) async {
    final deleted =
        await (_database.delete(_database.outbox)..where(
              (outbox) =>
                  outbox.entity.equals(entry.entity) &
                  outbox.rowId.equals(entry.rowId) &
                  outbox.revision.equals(entry.revision),
            ))
            .go();
    return deleted > 0;
  }

  Future<void> _reject(OutboxEntry entry, SyncRejection rejection) async {
    final serverRow = rejection.serverRow;
    if (serverRow != null) {
      // The server keeps its copy; show that instead of the refused edit.
      if (await _clear(entry)) {
        final table = _tableByEntity[entry.entity]!;
        await table.upsert(_database, table.fromServer(serverRow));
      }
      return;
    }
    // The server has no copy to restore. Keep the local row and stop
    // retrying until it is edited again.
    await (_database.update(_database.outbox)..where(
          (outbox) =>
              outbox.entity.equals(entry.entity) &
              outbox.rowId.equals(entry.rowId) &
              outbox.revision.equals(entry.revision),
        ))
        .write(OutboxCompanion(rejectedCode: Value(rejection.code)));
  }

  Future<void> _pull() async {
    final saved = await _database.readMeta(checkpointKey);
    var checkpoint = saved == null
        ? null
        : jsonDecode(saved) as Map<String, dynamic>;
    while (true) {
      final page = await _remote.pull(checkpoint);
      await _database.transaction(() async {
        final unpushed = {
          for (final entry in await _database.select(_database.outbox).get())
            (entry.entity, entry.rowId),
        };
        for (final pulled in page.rows) {
          final table = _tableByEntity[pulled.entity];
          final id = pulled.row['id'];
          if (table == null || id is! String) continue;
          if (unpushed.contains((pulled.entity, id))) continue;
          await table.upsert(_database, table.fromServer(pulled.row));
        }
        if (page.checkpoint case final next?) {
          await _database.writeMeta(checkpointKey, jsonEncode(next));
        }
      });
      checkpoint = page.checkpoint;
      if (!page.hasMore) return;
    }
  }
}
