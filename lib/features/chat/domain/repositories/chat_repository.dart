import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';

/// The chat between a consumer and a technician about one request. The
/// conversation is named by the request and the technician's id; both sides
/// pass the same two.
abstract interface class ChatRepository {
  /// The conversation, and clears the person's unread notice of it.
  Future<Result<Conversation>> fetchConversation(
    String requestId,
    String technicianId,
  );

  /// Sends [body]; the server refuses numbers and links.
  Future<Result<ChatMessage>> send(
    String requestId,
    String technicianId,
    String body,
  );
}
