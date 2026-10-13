part of 'chat_cubit.dart';

enum ChatLoadStatus { loading, ready, missing, failed }

final class ChatState extends Equatable {
  const ChatState({
    this.status = ChatLoadStatus.loading,
    this.conversation,
    this.sending = false,
    this.failure,
  });

  final ChatLoadStatus status;

  /// The conversation, once fetched; kept while a refresh fails.
  final Conversation? conversation;

  /// A message is on its way.
  final bool sending;

  /// Why the last message was not sent.
  final Failure? failure;

  ChatState copyWith({
    ChatLoadStatus? status,
    Conversation? conversation,
    bool? sending,
    Failure? Function()? failure,
  }) {
    return ChatState(
      status: status ?? this.status,
      conversation: conversation ?? this.conversation,
      sending: sending ?? this.sending,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, conversation, sending, failure];
}
