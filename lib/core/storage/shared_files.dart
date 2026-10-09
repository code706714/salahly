import 'dart:io';

/// Files made to hand to another app, like an invoice PDF sent on
/// WhatsApp. They hold customers' details, so they go with the rest of the
/// user's data on sign-out.
class SharedFiles {
  const SharedFiles(this._directory);

  final Directory _directory;

  /// Where to write a file named [name] before sharing it.
  Future<File> file(String name) async {
    await _directory.create(recursive: true);
    return File('${_directory.path}/$name');
  }

  Future<void> clear() async {
    if (_directory.existsSync()) await _directory.delete(recursive: true);
  }
}
