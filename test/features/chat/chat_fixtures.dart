import 'package:bloc_test/bloc_test.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/presentation/cubit/chat_cubit.dart';

class MockChatCubit extends MockCubit<ChatState> implements ChatCubit {}

ChatMessage testMessage({
  String id = 'message-1',
  bool mine = true,
  String body = 'الجهاز بيفصل كتير',
  DateTime? createdAt,
}) => ChatMessage(
  id: id,
  mine: mine,
  body: body,
  createdAt: createdAt ?? DateTime(2026, 10, 3, 10, 15),
);

Conversation testConversation({
  bool isOpen = true,
  String otherName = 'محمود عبد الله',
  Honorific? otherHonorific,
  List<ChatMessage>? messages,
}) => Conversation(
  isOpen: isOpen,
  otherName: otherName,
  otherHonorific: otherHonorific,
  messages:
      messages ??
      [
        testMessage(),
        testMessage(
          id: 'message-2',
          mine: false,
          body: 'تمام، هجيلك بكره',
          createdAt: DateTime(2026, 10, 3, 10, 20),
        ),
      ],
);
