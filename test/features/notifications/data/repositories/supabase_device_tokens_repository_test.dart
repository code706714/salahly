import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/notifications/data/repositories/supabase_device_tokens_repository.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late List<http.Request> requests;
  late int status;
  late Object? body;
  late bool offline;

  setUp(() {
    requests = [];
    status = 200;
    body = null;
    offline = false;
  });

  SupabaseDeviceTokensRepository repository() => SupabaseDeviceTokensRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        if (offline) throw const SocketException('offline');
        requests.add(request);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    ),
  );

  test('registers this phone with its platform', () async {
    final result = await repository().register(
      'token-abc',
      DevicePlatform.android,
    );

    expect(result, isA<Ok<void>>());
    expect(requests.single.url.path, '/rest/v1/rpc/register_device_token');
    expect(jsonDecode(requests.single.body), {
      'p_token': 'token-abc',
      'p_platform': 'android',
    });
  });

  test('unregisters this phone', () async {
    final result = await repository().unregister('token-abc');

    expect(result, isA<Ok<void>>());
    expect(requests.single.url.path, '/rest/v1/rpc/unregister_device_token');
    expect(jsonDecode(requests.single.body), {'p_token': 'token-abc'});
  });

  test('reports a failure instead of throwing', () async {
    status = 400;
    body = {'code': '22023', 'message': 'invalid_token', 'details': null};

    expect(
      await repository().register('x', DevicePlatform.ios),
      isA<Err<void>>(),
    );
  });

  test('says when there is no internet', () async {
    offline = true;

    expect(
      await repository().unregister('token-abc'),
      isA<Err<void>>().having(
        (err) => err.failure,
        'failure',
        const NetworkFailure(),
      ),
    );
  });
}
