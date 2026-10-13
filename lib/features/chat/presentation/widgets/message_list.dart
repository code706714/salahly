import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/chat/domain/entities/conversation.dart';

/// The messages of a chat, the newest at the bottom, with the day written
/// where it changes. Mine start at the reading edge, theirs at the other.
class MessageList extends StatelessWidget {
  const MessageList({required this.messages, super.key});

  /// Oldest first.
  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    final newestFirst = messages.reversed.toList();
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: newestFirst.length,
      itemBuilder: (context, index) {
        final message = newestFirst[index];
        final older = index + 1 < newestFirst.length
            ? newestFirst[index + 1]
            : null;
        return Column(
          children: [
            if (older == null || !_sameDay(older.createdAt, message.createdAt))
              _DayLabel(message.createdAt),
            _Bubble(message),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.time);

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        DateFormat('EEEE d MMMM', 'ar').format(time),
        style: TextStyle(fontSize: 13, color: context.appColors.inkMuted),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.message);

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mine = message.mine;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? colors.primarySoft : colors.surface,
          border: Border.all(color: mine ? colors.primarySoft : colors.border),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: TextStyle(fontSize: 16, height: 1.5, color: colors.ink),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('h:mm a', 'ar').format(message.createdAt),
              style: TextStyle(fontSize: 12, color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}
