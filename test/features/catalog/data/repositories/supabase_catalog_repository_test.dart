import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/storage/json_file_cache.dart';
import 'package:salahly/features/catalog/data/repositories/supabase_catalog_repository.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Directory directory;
  late JsonFileCache cache;
  late bool online;

  const rows = [
    {
      'id': 'heliopolis',
      'name_ar': 'مصر الجديدة',
      'city_ar': 'القاهرة',
      'center_lat': 30.0911,
      'center_lng': 31.3225,
    },
  ];

  setUp(() {
    directory = Directory.systemTemp.createTempSync();
    cache = JsonFileCache(File('${directory.path}/areas.json'));
    online = true;
  });

  tearDown(() => directory.deleteSync(recursive: true));

  SupabaseCatalogRepository repository() {
    final client = MockClient((request) async {
      if (!online) throw const SocketException('offline');
      expect(request.url.path, '/rest/v1/service_areas');
      return http.Response(
        jsonEncode(rows),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,
      );
    });
    return SupabaseCatalogRepository(
      SupabaseClient('https://example.supabase.co', 'key', httpClient: client),
      areasCache: cache,
    );
  }

  test('keeps the fetched areas for when there is no network', () async {
    final fetched = await repository().fetchAreas();
    expect(fetched, isA<Ok<List<ServiceArea>>>());
    expect(await cache.read(), rows);

    online = false;
    final offline = await repository().fetchAreas();

    expect(
      offline,
      isA<Ok<List<ServiceArea>>>().having(
        (result) => result.value.single.name,
        'name',
        'مصر الجديدة',
      ),
    );
  });

  test('fails offline when the areas were never fetched', () async {
    online = false;

    expect(
      await repository().fetchAreas(),
      isA<Err<List<ServiceArea>>>().having(
        (result) => result.failure,
        'failure',
        const NetworkFailure(),
      ),
    );
  });
}
