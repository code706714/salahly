import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The problems a job can be about, any number of them picked.
class TagChips extends StatelessWidget {
  const TagChips({required this.selected, required this.onToggle, super.key});

  final List<JobTag> selected;
  final ValueChanged<JobTag> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final tag in JobTag.values)
          ChoiceChipButton(
            label: jobTagLabel(l10n, tag),
            selected: selected.contains(tag),
            onTap: () => onToggle(tag),
          ),
      ],
    );
  }
}
