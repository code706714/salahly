import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// A message as it will look in the customer's WhatsApp chat, sent at
/// [sentAt].
class QuotePreview extends StatelessWidget {
  const QuotePreview({required this.message, required this.sentAt, super.key});

  final String message;
  final DateTime sentAt;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.border,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(AppRadii.md),
              bottomLeft: Radius.circular(AppRadii.md),
              bottomRight: Radius.circular(AppRadii.md),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.ink.withValues(alpha: 0.12),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontSize: 15, height: 1.75),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat.jm('ar').format(sentAt),
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
