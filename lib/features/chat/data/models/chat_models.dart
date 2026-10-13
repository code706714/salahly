import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';

/// Maps the chat functions' JSON to domain entities.
abstract final class ChatModels {
  static ChatMessage message(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    mine: json['mine'] as bool,
    body: json['body'] as String,
    createdAt: timeFromWire(json['created_at']),
  );

  static Conversation conversation(Map<String, dynamic> json) => Conversation(
    isOpen: json['open'] as bool,
    otherName: json['other_name'] as String,
    otherHonorific: json['other_honorific'] == null
        ? null
        : enumFromWire(Honorific.values, json['other_honorific']),
    messages: listFromWire(json['messages']).map(message).toList(),
  );
}
