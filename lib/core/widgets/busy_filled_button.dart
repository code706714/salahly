import 'package:flutter/material.dart';

/// The primary action button; shows a spinner and ignores taps while busy.
class BusyFilledButton extends StatelessWidget {
  const BusyFilledButton({
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    super.key,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? () {} : onPressed,
      child: isBusy
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            )
          : Text(label),
    );
  }
}
