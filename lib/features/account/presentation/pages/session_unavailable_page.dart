import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Shown when the user is signed in but their profile has never been
/// downloaded to this device and the server can't be reached.
class SessionUnavailablePage extends StatefulWidget {
  const SessionUnavailablePage({super.key});

  @override
  State<SessionUnavailablePage> createState() => _SessionUnavailablePageState();
}

class _SessionUnavailablePageState extends State<SessionUnavailablePage> {
  bool _isRetrying = false;

  Future<void> _retry() async {
    setState(() => _isRetrying = true);
    await context.read<SessionCubit>().refreshProfile();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: colors.inkMuted),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.sessionUnavailableTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.sessionUnavailableBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.inkMuted, height: 1.6),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _isRetrying ? null : _retry,
                child: Text(l10n.retry),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: context.read<SessionCubit>().signOut,
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
