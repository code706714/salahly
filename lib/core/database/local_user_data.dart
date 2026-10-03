import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/core/storage/user_scoped_data.dart';

/// The technician's records, photos and shared files on this phone.
class LocalUserData implements UserScopedData {
  const LocalUserData(this._database, this._photos, this._sharedFiles);

  static const ownerKey = 'owner';

  final AppDatabase _database;
  final LocalPhotoStore _photos;
  final SharedFiles _sharedFiles;

  @override
  Future<void> claimFor(String userId) async {
    if (await _database.readMeta(ownerKey) == userId) return;
    await clear();
    await _database.writeMeta(ownerKey, userId);
  }

  @override
  Future<void> clear() async {
    await _database.wipe();
    await _photos.clear();
    await _sharedFiles.clear();
  }
}
