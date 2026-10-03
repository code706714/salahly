import 'dart:convert';
import 'dart:io';

/// The last copy of some server rows, kept in a file so screens can show
/// them without a network. Holds reference data only, never user data.
class JsonFileCache {
  JsonFileCache(this._file);

  final File _file;

  /// The rows last written, or null when there are none or the file is
  /// unreadable.
  Future<List<Map<String, dynamic>>?> read() async {
    try {
      final decoded = jsonDecode(await _file.readAsString());
      return (decoded as List<dynamic>).cast<Map<String, dynamic>>();
    } on Object {
      return null;
    }
  }

  Future<void> write(List<Map<String, dynamic>> rows) async {
    await _file.parent.create(recursive: true);
    await _file.writeAsString(jsonEncode(rows), flush: true);
  }
}
