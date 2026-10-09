import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';

/// Asks the consumer before a step that can't be taken back. Resolves to
/// true when they [confirm]; [destructive] colors that choice as a loss.
Future<bool> showConfirmChoiceDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String keep,
  required String confirm,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.appColors;
      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        content: Text(
          body,
          style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(keep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? colors.danger : colors.primary,
            ),
            child: Text(confirm),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
