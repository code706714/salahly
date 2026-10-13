import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/live_refresh.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/chat/domain/failures/chat_failures.dart';
import 'package:salahly/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:salahly/features/chat/presentation/widgets/chat_composer.dart';
import 'package:salahly/features/chat/presentation/widgets/message_list.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The chat between a consumer and a technician about one request, the same
/// screen on both sides.
class ChatPage extends StatelessWidget {
  const ChatPage({
    required this.role,
    required this.requestId,
    required this.technicianId,
    super.key,
  });

  /// Which side of the app the chat is on.
  final UserRole role;
  final String requestId;
  final String technicianId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ChatCubit(
          chats: context.read(),
          requestId: requestId,
          technicianId: technicianId,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: ChatView(
        onCall: (name) => unawaited(
          context.push(
            AppRoutes.call(
              role,
              requestId: requestId,
              technicianId: technicianId,
              name: name,
            ),
          ),
        ),
      ),
    );
  }
}

class ChatView extends StatelessWidget {
  const ChatView({this.onCall, super.key});

  /// Starts a voice call with the person called `name`; no call button
  /// without it.
  final void Function(String name)? onCall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<ChatCubit>();
    final state = cubit.state;
    final conversation = state.conversation;
    return LiveRefresh(
      onChange: cubit.refresh,
      child: BlocListener<ChatCubit, ChatState>(
        listenWhen: (previous, current) =>
            previous.failure != current.failure && current.failure != null,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(_failureMessage(l10n, state.failure!))),
          ),
        child: Scaffold(
          appBar: DetailHeader(
            title: l10n.chatTitle,
            subtitle: conversation?.otherName,
            trailing: switch ((onCall, conversation)) {
              (final onCall?, final conversation?) when conversation.isOpen =>
                IconButton(
                  tooltip: l10n.callButton,
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => onCall(conversation.otherName),
                ),
              _ => null,
            },
          ),
          body: switch (state.status) {
            ChatLoadStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            ChatLoadStatus.missing || ChatLoadStatus.failed => _Unavailable(
              missing: state.status == ChatLoadStatus.missing,
              onRetry: cubit.refresh,
            ),
            ChatLoadStatus.ready => _Conversation(
              state: state,
              onSend: cubit.send,
            ),
          },
        ),
      ),
    );
  }
}

String _failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      ContactBlockedFailure() => l10n.chatContactBlocked,
      ChatClosedFailure() => l10n.chatClosed,
      ChatUnavailableFailure() => l10n.marketplaceNotFound,
      _ => commonFailureMessage(l10n, failure),
    };

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.missing, required this.onRetry});

  final bool missing;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              missing ? l10n.marketplaceNotFound : l10n.chatLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.appColors.inkMuted,
              ),
            ),
            if (!missing) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Conversation extends StatefulWidget {
  const _Conversation({required this.state, required this.onSend});

  final ChatState state;
  final Future<bool> Function(String text) onSend;

  @override
  State<_Conversation> createState() => _ConversationState();
}

class _ConversationState extends State<_Conversation> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text;
    if (await widget.onSend(text)) _text.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final conversation = widget.state.conversation!;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: colors.noticeSoft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, size: 18, color: colors.inkMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatSafetyNote,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: conversation.messages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l10n.chatEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: colors.inkMuted),
                    ),
                  ),
                )
              : MessageList(messages: conversation.messages),
        ),
        if (conversation.isOpen)
          ChatComposer(
            controller: _text,
            sending: widget.state.sending,
            onSend: _send,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Text(
                l10n.chatClosed,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: colors.inkMuted),
              ),
            ),
          ),
      ],
    );
  }
}
