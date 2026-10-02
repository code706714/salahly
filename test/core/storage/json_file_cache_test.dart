import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/storage/json_file_cache.dart';

void main() {
  late Directory directory;

  setUp(() => directory = Directory.systemTemp.createTempSync());
  tearDown(() => directory.deleteSync(recursive: true));

  test('reads back the rows it wrote, creating folders as needed', () async {
    final cache = JsonFileCache(File('${directory.path}/catalog/areas.json'));
    final rows = [
      {'id': 'heliopolis', 'name_ar': 'مصر الجديدة', 'center_lat': 30.09},
    ];

    await cache.write(rows);

    expect(await cache.read(), rows);
  });

  test('has nothing before the first write', () async {
    final cache = JsonFileCache(File('${directory.path}/areas.json'));

    expect(await cache.read(), isNull);
  });

  test('treats a damaged file as empty', () async {
    final file = File('${directory.path}/areas.json')
      ..writeAsStringSync('{not json');

    expect(await JsonFileCache(file).read(), isNull);
  });
}
