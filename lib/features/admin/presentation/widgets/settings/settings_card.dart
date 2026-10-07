import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';

/// A titled panel of the settings page, with an optional note under it and
/// controls beside the title.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    required this.title,
    required this.child,
    this.note,
    this.trailing,
    super.key,
  });

  final String title;
  final String? note;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: TextStyle(fontSize: 13, color: colors.inkMuted),
              ),
            ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
