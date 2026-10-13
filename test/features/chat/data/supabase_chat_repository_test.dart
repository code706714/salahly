import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/chat/data/repositories/supabase_chat_repository.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
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

  SupabaseChatRepository repository() => SupabaseChatRepository(
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

  void refuse(String message, {String code = 'P0001'}) {
    status = 400;
    body = {'code': code, 'message': message, 'details': null};
  }

  group('reading the conversation', () {
    test(
      'reads who it is with, whether it is open, and the messages',
      () async {
        body = {
          'open': true,
          'other_name': 'نورهان م.',
          'other_honorific': 'ms',
          'messages': [
            {
              'id': 'message-1',
              'mine': false,
              'body': 'هتيجي امتى؟',
              'created_at': '2026-10-03T10:15:00+00:00',
            },
            {
              'id': 'message-2',
              'mine': true,
              'body': 'بكره الضهر',
              'created_at': '2026-10-03T10:16:00+00:00',
            },
          ],
        };

        final result = await repository().fetchConversation(
          'request-1',
          'technician-1',
        );

        expect(requests.single.url.path, '/rest/v1/rpc/chat_messages');
        expect(jsonDecode(requests.single.body), {
          'p_request_id': 'request-1',
          'p_technician_id': 'technician-1',
        });
        final conversation = (result as Ok<Conversation>).value;
        expect(conversation.isOpen, isTrue);
        expect(conversation.otherName, 'نورهان م.');
        expect(conversation.otherHonorific, Honorific.ms);
        expect(conversation.messages.map((m) => (m.id, m.mine, m.body)), [
          ('message-1', false, 'هتيجي امتى؟'),
          ('message-2', true, 'بكره الضهر'),
        ]);
        expect(
          conversation.messages.first.createdAt,
          DateTime.utc(2026, 10, 3, 10, 15).toLocal(),
        );
      },
    );

    test(
      'reads a closed conversation with no messages and no honorific',
      () async {
        body = {
          'open': false,
          'other_name': 'محمود عبد الله',
          'other_honorific': null,
          'messages': <Object?>[],
        };

        final result = await repository().fetchConversation('r', 't');

        final conversation = (result as Ok<Conversation>).value;
        expect(conversation.isOpen, isFalse);
        expect(conversation.otherHonorific, isNull);
        expect(conversation.messages, isEmpty);
      },
    );

    test("says when the conversation is not the caller's", () async {
      refuse('chat_unavailable');

      expect(
        await repository().fetchConversation('r', 't'),
        isA<Err<Conversation>>().having(
          (err) => err.failure,
          'failure',
          const ChatUnavailableFailure(),
        ),
      );
    });

    test('says when the network is down', () async {
      offline = true;

      expect(
        await repository().fetchConversation('r', 't'),
        isA<Err<Conversation>>().having(
          (err) => err.failure,
          'failure',
          const NetworkFailure(),
        ),
      );
    });
  });

  group('sending', () {
    test('sends the text and reads the message back', () async {
      body = {
        'id': 'message-9',
        'mine': true,
        'body': 'تمام',
        'created_at': '2026-10-03T10:20:00+00:00',
      };

      final result = await repository().send(
        'request-1',
        'technician-1',
        'تمام',
      );

      expect(requests.single.url.path, '/rest/v1/rpc/send_chat_message');
      expect(jsonDecode(requests.single.body), {
        'p_request_id': 'request-1',
        'p_technician_id': 'technician-1',
        'p_body': 'تمام',
      });
      expect((result as Ok<ChatMessage>).value.id, 'message-9');
    });

    for (final (message, code, failure) in <(String, String, Failure)>[
      ('chat_closed', 'P0001', const ChatClosedFailure()),
      ('chat_unavailable', 'P0001', const ChatUnavailableFailure()),
      ('contact_blocked', 'P0001', const ContactBlockedFailure()),
      ('rate_limited', '54000', const RateLimitedFailure()),
    ]) {
      test('says why it was refused: $message', () async {
        refuse(message, code: code);

        expect(
          await repository().send('r', 't', 'مرحبا'),
          isA<Err<ChatMessage>>().having(
            (err) => err.failure,
            'failure',
            failure,
          ),
        );
      });
    }
  });
}
