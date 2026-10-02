import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The technician's start screen. Milestone 2 adds the day's jobs, the
/// customers and money tabs; this version greets and shows verification.
class TechnicianHomePage extends StatelessWidget {
  const TechnicianHomePage({super.key});

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
    final status = profile.technician?.verificationStatus;
    final today = DateFormat('EEEE d MMMM', 'ar').format(DateTime.now());

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
            Text(today, style: TextStyle(fontSize: 14, color: colors.inkMuted)),
            const SizedBox(height: 2),
            Text(
              l10n.greeting(profile.firstName),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            if (status == VerificationStatus.pending)
              _Banner(
                icon: Icons.schedule_rounded,
                background: colors.warningSoft,
                foreground: colors.warning,
                title: l10n.techPendingTitle,
                body: l10n.techPendingBody,
              )
            else if (status == VerificationStatus.rejected)
              _Banner(
                icon: Icons.error_outline_rounded,
                background: colors.primarySoft,
                foreground: colors.primaryPressed,
                title: l10n.techRejectedTitle,
                body: l10n.techRejectedBody,
              ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: foreground, fontSize: 14, height: 1.6),
                children: [
                  TextSpan(
                    text: '$title\n',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
