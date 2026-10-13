import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
import 'package:salahly/features/chat/presentation/cubit/chat_cubit.dart';

import '../../../../helpers/mocks.dart';
import '../../chat_fixtures.dart';

void main() {
  late MockChatRepository chats;

  setUp(() => chats = MockChatRepository());

  ChatCubit cubitFor({Duration pollEvery = const Duration(seconds: 4)}) =>
      ChatCubit(
        chats: chats,
        requestId: 'request-1',
        technicianId: 'technician-1',
        pollEvery: pollEvery,
      );

  group('loading', () {
    test('shows the conversation', () async {
      final conversation = testConversation();
      when(
        () => chats.fetchConversation('request-1', 'technician-1'),
      ).thenAnswer((_) async => Ok(conversation));
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, ChatLoadStatus.ready);
      expect(cubit.state.conversation, conversation);
      await cubit.close();
    });

    test('says when the conversation is not there for the caller', () async {
      when(
        () => chats.fetchConversation(any(), any()),
      ).thenAnswer((_) async => const Err(ChatUnavailableFailure()));
      final cubit = cubitFor();

      await cubit.start();

      expect(cubit.state.status, ChatLoadStatus.missing);
      await cubit.close();
    });

    test(
      'fails without a conversation, and keeps one it already has',
      () async {
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        final cubit = cubitFor();

        await cubit.start();
        expect(cubit.state.status, ChatLoadStatus.failed);

        final conversation = testConversation();
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => Ok(conversation));
        await cubit.refresh();
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        await cubit.refresh();

        expect(cubit.state.status, ChatLoadStatus.ready);
        expect(cubit.state.conversation, conversation);
        await cubit.close();
      },
    );

    test('checks for new messages while the chat is open', () {
      fakeAsync((async) {
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => Ok(testConversation()));
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        verify(() => chats.fetchConversation(any(), any())).called(1);

        final replied = testConversation(
          messages: [
            testMessage(),
            testMessage(id: 'm2', mine: false),
          ],
        );
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => Ok(replied));
        async.elapse(const Duration(seconds: 4));
        expect(cubit.state.conversation, replied);

        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('stops checking once the chat is closed', () {
      fakeAsync((async) {
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => Ok(testConversation(isOpen: false)));
        final cubit = cubitFor();
        unawaited(cubit.start());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 1));

        verify(() => chats.fetchConversation(any(), any())).called(1);
        unawaited(cubit.close());
        async.flushMicrotasks();
      });
    });

    test('stops checking once the cubit is closed', () {
      fakeAsync((async) {
        when(
          () => chats.fetchConversation(any(), any()),
        ).thenAnswer((_) async => Ok(testConversation()));
        final cubit = cubitFor();
        unawaited(cubit.start());
        async.flushMicrotasks();
        unawaited(cubit.close());
        async
          ..flushMicrotasks()
          ..elapse(const Duration(minutes: 1));

        verify(() => chats.fetchConversation(any(), any())).called(1);
      });
    });
  });

  group('sending', () {
    setUp(() {
      when(
        () => chats.fetchConversation(any(), any()),
      ).thenAnswer((_) async => Ok(testConversation()));
    });

    test('sends the trimmed text and fetches the conversation again', () async {
      when(
        () => chats.send('request-1', 'technician-1', 'تمام'),
      ).thenAnswer((_) async => Ok(testMessage(body: 'تمام')));
      final cubit = cubitFor();
      await cubit.start();

      final sent = await cubit.send('  تمام  ');

      expect(sent, isTrue);
      expect(cubit.state.sending, isFalse);
      verify(() => chats.send('request-1', 'technician-1', 'تمام')).called(1);
      verify(() => chats.fetchConversation(any(), any())).called(2);
      await cubit.close();
    });

    test('sends nothing for an empty message', () async {
      final cubit = cubitFor();
      await cubit.start();

      expect(await cubit.send('   '), isFalse);
      verifyNever(() => chats.send(any(), any(), any()));
      await cubit.close();
    });

    test(
      'shows why a message was refused and keeps the conversation',
      () async {
        when(
          () => chats.send(any(), any(), any()),
        ).thenAnswer((_) async => const Err(ContactBlockedFailure()));
        final cubit = cubitFor();
        await cubit.start();

        final sent = await cubit.send('كلمني 01012345678');

        expect(sent, isFalse);
        expect(cubit.state.failure, const ContactBlockedFailure());
        expect(cubit.state.sending, isFalse);
        expect(cubit.state.conversation, testConversation());

        when(
          () => chats.send(any(), any(), any()),
        ).thenAnswer((_) async => Ok(testMessage()));
        await cubit.send('تمام');
        expect(cubit.state.failure, isNull);
        await cubit.close();
      },
    );

    test('does not send a second message while one is on its way', () async {
      final gate = Completer<Result<ChatMessage>>();
      when(
        () => chats.send(any(), any(), any()),
      ).thenAnswer((_) => gate.future);
      final cubit = cubitFor();
      await cubit.start();

      final first = cubit.send('أول');
      expect(cubit.state.sending, isTrue);
      expect(await cubit.send('تاني'), isFalse);

      gate.complete(Ok(testMessage()));
      await first;
      verify(() => chats.send(any(), any(), any())).called(1);
      await cubit.close();
    });
  });
}
