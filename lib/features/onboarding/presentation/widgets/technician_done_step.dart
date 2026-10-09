import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/free_uses_badge.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "We got your details": shown once the ID photos are submitted.
class TechnicianDoneStep extends StatelessWidget {
  const TechnicianDoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final freeJobs = context.select<TechnicianOnboardingCubit, int>(
      (cubit) => cubit.state.freeJobs,
    );
    const bold = TextStyle(fontWeight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        spacing: 14,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: colors.warningSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 40,
              color: colors.warning,
            ),
          ),
          Text(
            l10n.techDoneTitle,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          Text(
            l10n.techDoneBody,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, height: 1.7, color: colors.inkMuted),
          ),
          if (freeJobs > 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: colors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  FreeUsesBadge(
                    count: freeJobs,
                    background: colors.primarySoft,
                    foreground: colors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 15, height: 1.6),
                        children: [
                          TextSpan(text: l10n.techFreeJobsLead),
                          TextSpan(
                            text: l10n.freeJobsCount(freeJobs),
                            style: bold,
                          ),
                          TextSpan(text: l10n.techFreeJobsMiddle),
                          TextSpan(text: l10n.techFreeJobsFree, style: bold),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
