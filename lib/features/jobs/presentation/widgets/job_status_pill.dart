import 'package:flutter/material.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where a job stands, as a pill: "اتأكد", "لسه ماتأكدش", ...
class JobStatusPill extends StatelessWidget {
  const JobStatusPill(this.status, {super.key});

  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon) = switch (status) {
      JobStatus.unconfirmed => (PillTone.attention, Icons.schedule_rounded),
      JobStatus.confirmed ||
      JobStatus.finished ||
      JobStatus.paid => (PillTone.success, Icons.check_rounded),
      JobStatus.started => (PillTone.waiting, Icons.handyman_outlined),
      JobStatus.cancelled => (PillTone.danger, Icons.close_rounded),
    };
    return StatusPill(
      label: jobStatusLabel(AppLocalizations.of(context), status),
      tone: tone,
      icon: icon,
    );
  }
}
