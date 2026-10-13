import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/chat/data/models/chat_models.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
import 'package:salahly/features/chat/domain/repositories/chat_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Conversation>> fetchConversation(
    String requestId,
    String technicianId,
  ) => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'chat_messages',
      params: {'p_request_id': requestId, 'p_technician_id': technicianId},
    );
    return ChatModels.conversation(json);
  });

  @override
  Future<Result<ChatMessage>> send(
    String requestId,
    String technicianId,
    String body,
  ) => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'send_chat_message',
      params: {
        'p_request_id': requestId,
        'p_technician_id': technicianId,
        'p_body': body,
      },
    );
    return ChatModels.message(json);
  });

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) {
    if (error is PostgrestException) {
      switch (error.message) {
        case 'chat_unavailable':
          return const ChatUnavailableFailure();
        case 'chat_closed':
          return const ChatClosedFailure();
        case 'contact_blocked':
          return const ContactBlockedFailure();
        case 'rate_limited':
          return const RateLimitedFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
