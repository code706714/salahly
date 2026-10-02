import 'package:flutter/material.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Full-screen message for a screen whose data couldn't load.
class LoadFailureView extends StatelessWidget {
  const LoadFailureView({
    required this.failure,
    required this.onRetry,
    super.key,
  });

  final Failure? failure;
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
              commonFailureMessage(
                l10n,
                failure ?? const UnexpectedFailure(),
              ),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
