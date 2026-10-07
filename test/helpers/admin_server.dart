import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers every call with [body] (JSON) and [status], recording requests,
/// so a repository can be tried against a real [SupabaseClient].
class AdminServer {
  Object? body;
  int status = 200;
  bool offline = false;
  final requests = <http.Request>[];

  late final SupabaseClient client = SupabaseClient(
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
  );

  http.Request get last => requests.last;

  /// The function the last call reached.
  String get lastFunction => last.url.pathSegments.last;

  Map<String, dynamic> get lastParams =>
      jsonDecode(last.body) as Map<String, dynamic>;

  /// Makes the server raise [message] the way the admin functions do.
  void fails(String message) {
    status = 400;
    body = {'code': 'P0001', 'message': message, 'details': null};
  }
}

Matcher failsWith(Failure failure) =>
    isA<Err<Object?>>().having((err) => err.failure, 'failure', failure);

T valueOf<T>(Result<T> result) => (result as Ok<T>).value;
