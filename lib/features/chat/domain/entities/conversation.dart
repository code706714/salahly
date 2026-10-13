import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';

/// One line of a chat.
final class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.body,
    required this.createdAt,
  });

  final String id;

  /// Whether the person reading wrote it.
  final bool mine;
  final String body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, mine, body, createdAt];
}

/// The talk between a consumer and one technician who offered on her
/// request, as the person on either side reads it.
final class Conversation extends Equatable {
  const Conversation({
    required this.isOpen,
    required this.otherName,
    required this.messages,
    this.otherHonorific,
  });

  /// Whether it still takes messages.
  final bool isOpen;

  /// The other side: the technician's name, or the consumer's short name.
  final String otherName;

  /// The consumer's honorific, when the reader is the technician.
  final Honorific? otherHonorific;

  /// Oldest first.
  final List<ChatMessage> messages;

  @override
  List<Object?> get props => [isOpen, otherName, otherHonorific, messages];
}
