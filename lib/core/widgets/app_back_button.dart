import 'package:flutter/material.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A 48x48 back chevron that points the reading direction's way back.
class AppBackButton extends StatelessWidget {
  const AppBackButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: AppLocalizations.of(context).back,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
    );
  }
}
