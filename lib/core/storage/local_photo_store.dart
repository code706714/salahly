import 'dart:io';

/// Job photos kept on the phone, one file per photo id.
///
/// Photos are taken offline and uploaded later, so the file must outlive
/// the picker's temporary copy. Files live in the app's private storage.
class LocalPhotoStore {
  const LocalPhotoStore(this._directory);

  final Directory _directory;

  File fileFor(String photoId) => File('${_directory.path}/$photoId.jpg');

  /// Moves the picked photo at [sourcePath] into the store.
  Future<File> keep(String photoId, String sourcePath) async {
    await _directory.create(recursive: true);
    final source = File(sourcePath);
    final target = fileFor(photoId);
    try {
      return await source.rename(target.path);
    } on FileSystemException {
      // Rename fails across file systems; copy instead.
      final copy = await source.copy(target.path);
      await source.delete();
      return copy;
    }
  }

  Future<void> clear() async {
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }
}
