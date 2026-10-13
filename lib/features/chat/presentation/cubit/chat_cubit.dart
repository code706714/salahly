import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
import 'package:salahly/features/chat/domain/repositories/chat_repository.dart';

part 'chat_state.dart';

/// One conversation about a request, between the consumer and a technician.
///
/// The other side's messages arrive from the server, so the conversation is
/// fetched again every `pollEvery` while it is open and on screen, and
/// whenever the server reports something new for the person.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required this._chats,
    required this._requestId,
    required this._technicianId,
    this._pollEvery = const Duration(seconds: 4),
  }) : super(const ChatState());

  final ChatRepository _chats;
  final String _requestId;
  final String _technicianId;
  final Duration _pollEvery;
  Timer? _poll;
  late final _fetch = SingleFlight(_fetchConversation);

  /// Fetches the conversation and keeps it fresh until the cubit closes.
  Future<void> start() async {
    _poll ??= Timer.periodic(_pollEvery, (_) {
      if (state.conversation?.isOpen ?? true) unawaited(refresh());
    });
    await refresh();
  }

  /// Fetches the conversation again. A failed refresh keeps what is shown.
  Future<void> refresh() => _fetch();

  Future<void> _fetchConversation() async {
    final result = await _chats.fetchConversation(_requestId, _technicianId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: ChatLoadStatus.ready, conversation: value),
        );
      case Err(failure: ChatUnavailableFailure()):
        emit(state.copyWith(status: ChatLoadStatus.missing));
      case Err() when state.conversation != null:
        break;
      case Err():
        emit(state.copyWith(status: ChatLoadStatus.failed));
    }
  }

  /// Sends [text]; true once the server took it. The failure, if any, is in
  /// the state until the next send.
  Future<bool> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || state.sending) return false;
    emit(state.copyWith(sending: true, failure: () => null));
    final result = await _chats.send(_requestId, _technicianId, body);
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(state.copyWith(sending: false));
        await refresh();
        return true;
      case Err(:final failure):
        emit(state.copyWith(sending: false, failure: () => failure));
        return false;
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
