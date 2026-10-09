import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/features/onboarding/presentation/widgets/location_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianLocationStep extends StatelessWidget {
  const TechnicianLocationStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TechnicianOnboardingCubit>();
    final state = context.watch<TechnicianOnboardingCubit>().state;
    final base = state.baseArea;
    final days = [
      for (final weekday in const [6, 7, 1, 2, 3, 4, 5])
        (weekday, weekdayShortName(l10n, weekday)),
    ];

    Future<void> pickBase() async {
      final area = await showAreaPicker(context, areas: state.areas);
      if (area != null) cubit.basePicked(area);
    }

    Future<void> addArea() async {
      final area = await showAreaPicker(context, areas: state.areas);
      if (area != null && !state.areaIds.contains(area.id)) {
        cubit.areaToggled(area.id);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(
          l10n.techLocationTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        LocationCard(
          isChosen: base != null,
          isBusy: state.isLocating,
          hasError: state.showErrors && base == null,
          onTap: state.isLocating ? null : pickBase,
          title: state.isLocating
              ? l10n.areaDetecting
              : base == null
              ? l10n.techBaseRequired
              : l10n.techBaseArea(base.name),
          subtitle: switch ((base, state.locationFailure)) {
            _ when state.isLocating => null,
            (_?, _) when state.baseSource == AreaSource.location =>
              l10n.techBaseFromGps,
            (_?, _) => l10n.areaChosenByHand,
            (null, LocationDisabledFailure()) => l10n.locationServiceOff,
            (null, _?) => l10n.locationDenied,
            (null, null) => null,
          },
        ),
        FieldLabel(l10n.techRadiusLabel),
        Row(
          spacing: 8,
          children: [
            for (final km in TechnicianOnboardingState.radiusOptions)
              Expanded(
                child: ChoiceChipButton(
                  label: l10n.radiusKm(km),
                  selected: state.radiusKm == km,
                  onTap: () => cubit.radiusChanged(km),
                ),
              ),
          ],
        ),
        FieldLabel(l10n.techAreasLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final area in state.suggestedAreas)
              ChoiceChipButton(
                label: area.name,
                selected: state.areaIds.contains(area.id),
                onTap: () => cubit.areaToggled(area.id),
              ),
            ChoiceChipButton(
              label: l10n.techAreasMore,
              selected: false,
              onTap: addArea,
            ),
          ],
        ),
        if (state.showErrors && state.areaIds.isEmpty)
          FieldError(l10n.techAreasRequired),
        FieldLabel(l10n.techWorkDaysLabel),
        Row(
          spacing: 4,
          children: [
            for (final (day, label) in days)
              Expanded(
                child: ChoiceChipButton(
                  label: label,
                  selected: state.workDays.contains(day),
                  onTap: () => cubit.workDayToggled(day),
                  fontSize: 13,
                  padding: EdgeInsets.zero,
                ),
              ),
          ],
        ),
        if (state.showErrors && state.workDays.isEmpty)
          FieldError(l10n.techWorkDaysRequired),
      ],
    );
  }
}
