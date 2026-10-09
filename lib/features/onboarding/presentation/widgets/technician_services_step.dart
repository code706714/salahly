import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/catalog/presentation/widgets/service_price_picker.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianServicesStep extends StatelessWidget {
  const TechnicianServicesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOnboardingCubit>();
    final state = context.watch<TechnicianOnboardingCubit>().state;

    String? error;
    if (state.showErrors && state.selectedServiceIds.isEmpty) {
      error = l10n.techServicesRequired;
    } else if (state.showErrors && !state.isServicesValid) {
      error = l10n.techPriceInvalid;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(
          l10n.techServicesTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          l10n.techServicesHint,
          style: TextStyle(fontSize: 14, height: 1.6, color: colors.inkMuted),
        ),
        ServicePricePicker(
          categories: state.categories,
          selectedIds: state.selectedServiceIds,
          priceTexts: state.priceTexts,
          invalidIds: {
            if (state.showErrors)
              for (final id in state.selectedServiceIds)
                if (state.pricePiastres(id) == null) id,
          },
          onToggle: cubit.serviceToggled,
          onPriceChanged: cubit.priceChanged,
        ),
        FieldError(error),
      ],
    );
  }
}
