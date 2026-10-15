import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/calls/data/repositories/supabase_call_repository.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/failures/call_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Object? body;
  late int status;
  late bool offline;
  late List<http.Request> requests;

  setUp(() {
    body = null;
    status = 200;
    offline = false;
    requests = [];
  });

  SupabaseCallRepository repository() => SupabaseCallRepository(
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

  void refuse(String message) {
    status = 400;
    body = {'code': 'P0001', 'message': message, 'details': null};
  }

  Map<String, dynamic> sent() =>
      jsonDecode(requests.single.body) as Map<String, dynamic>;

  group('the servers for the voice link', () {
    test('are the ones the function gives', () async {
      body = {
        'iceServers': [
          {
            'urls': ['turn:relay.example:3478'],
            'username': 'u',
            'credential': 'c',
          },
        ],
      };

      final servers = await repository().iceServers();

      expect(requests.single.url.path, '/functions/v1/call-ice-servers');
      expect(servers, [
        {
          'urls': ['turn:relay.example:3478'],
          'username': 'u',
          'credential': 'c',
        },
      ]);
    });

    test('are a public STUN server when the function fails', () async {
      status = 500;
      body = {'error': 'down'};

      final servers = await repository().iceServers();

      expect(servers, [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]);
    });

    test('are a public STUN server offline', () async {
      offline = true;

      expect(await repository().iceServers(), hasLength(1));
    });

    test('are a public STUN server when the answer has none', () async {
      body = {'iceServers': []};

      expect(await repository().iceServers(), hasLength(1));
    });
  });

  group('starting a call', () {
    test('names the request and the technician, and reads the id', () async {
      body = {'id': 'call-1'};

      final result = await repository().start('request-1', 'tech-1');

      expect(result, isA<Ok<String>>().having((r) => r.value, 'id', 'call-1'));
      expect(requests.single.url.path, '/rest/v1/rpc/start_call');
      expect(sent(), {
        'p_request_id': 'request-1',
        'p_technician_id': 'tech-1',
      });
    });

    for (final (message, failure) in <(String, Matcher)>[
      ('call_unavailable', isA<CallUnavailableFailure>()),
      ('call_in_progress', isA<CallInProgressFailure>()),
      ('callee_busy', isA<CalleeBusyFailure>()),
      ('rate_limited', isA<RateLimitedFailure>()),
    ]) {
      test('reads $message', () async {
        refuse(message);

        final result = await repository().start('request-1', 'tech-1');

        expect(
          result,
          isA<Err<String>>().having((r) => r.failure, 'f', failure),
        );
      });
    }

    test('reports being offline', () async {
      offline = true;

      final result = await repository().start('request-1', 'tech-1');

      expect(
        result,
        isA<Err<String>>().having((r) => r.failure, 'f', isA<NetworkFailure>()),
      );
    });
  });

  group('the call in progress', () {
    test('answers by id', () async {
      body = null;

      final result = await repository().answer('call-1');

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, '/rest/v1/rpc/answer_call');
      expect(sent(), {'p_call_id': 'call-1'});
    });

    test('ends by id', () async {
      body = null;

      await repository().end('call-1');

      expect(requests.single.url.path, '/rest/v1/rpc/end_call');
      expect(sent(), {'p_call_id': 'call-1'});
    });

    test("sends a handshake message with the server's name for it", () async {
      body = null;

      await repository().sendSignal(
        'call-1',
        const CallSignalDraft(CallSignalKind.candidate, {'candidate': 'x'}),
      );

      expect(requests.single.url.path, '/rest/v1/rpc/send_call_signal');
      expect(sent(), {
        'p_call_id': 'call-1',
        'p_kind': 'candidate',
        'p_payload': {'candidate': 'x'},
      });
    });
  });

  group('a call ringing', () {
    test('reads who is calling', () async {
      body = {
        'id': 'call-1',
        'request_id': 'request-1',
        'technician_id': 'tech-1',
        'caller_name': 'نورهان م.',
        'created_at': '2026-10-14T10:00:00+00:00',
      };

      final result = await repository().pending();

      expect(result, isA<Ok<IncomingCall?>>());
      final call = (result as Ok<IncomingCall?>).value!;
      expect(call.id, 'call-1');
      expect(call.requestId, 'request-1');
      expect(call.technicianId, 'tech-1');
      expect(call.callerName, 'نورهان م.');
    });

    test('reads none when nothing is ringing', () async {
      body = null;

      final result = await repository().pending();

      expect(result, isA<Ok<IncomingCall?>>());
      expect((result as Ok<IncomingCall?>).value, isNull);
    });
  });
}
