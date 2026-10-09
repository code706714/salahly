import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Four bars for confirmed, started, finished and paid: the steps done in
/// green, the one ahead in the brand color.
class JobProgressSteps extends StatelessWidget {
  const JobProgressSteps({required this.status, super.key});

  /// Not cancelled.
  final JobStatus status;

  /// How many of the four steps are done.
  int get _done => switch (status) {
    JobStatus.unconfirmed || JobStatus.cancelled => 0,
    JobStatus.confirmed => 1,
    JobStatus.started => 2,
    JobStatus.finished => 3,
    JobStatus.paid => 4,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final labels = [
      l10n.jobPageStepConfirmed,
      l10n.jobPageStepStarted,
      l10n.jobPageStepFinished,
      l10n.jobPageStepPaid,
    ];
    final done = _done;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (index, label) in labels.indexed) ...[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              selected: index == done,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: index < done
                          ? colors.successBright
                          : index == done
                          ? colors.primary
                          : colors.border,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: index < done
                          ? colors.success
                          : index == done
                          ? colors.primaryPressed
                          : colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
