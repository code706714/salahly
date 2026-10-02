import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumer's start screen. Milestone 3 adds requesting a technician
/// and offers; this version greets and shows the free requests left.
class ConsumerHomePage extends StatelessWidget {
  const ConsumerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    // Briefly null while signing out, before the redirect.
    if (profile == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final consumer = profile.consumer;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          children: [
            if (consumer != null)
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 18,
                    color: colors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    consumer.areaName,
                    style: TextStyle(fontSize: 14, color: colors.inkMuted),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.greeting(profile.firstName),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            if (consumer != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.consumerCreditsLeft(consumer.requestCredits),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: colors.primaryPressed,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
