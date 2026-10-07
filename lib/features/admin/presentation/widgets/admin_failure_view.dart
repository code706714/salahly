import 'package:flutter/material.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Says why something could not load, with a button to try again.
class AdminFailureView extends StatelessWidget {
  const AdminFailureView({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              adminFailureMessage(l10n, failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: context.appColors.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

/// A line telling that a list has nothing to show.
class AdminEmptyView extends StatelessWidget {
  const AdminEmptyView(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.appColors.inkMuted,
          ),
        ),
      ),
    );
  }
}
