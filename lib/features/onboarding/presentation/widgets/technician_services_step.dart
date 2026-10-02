import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianServicesStep extends StatelessWidget {
  const TechnicianServicesStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<TechnicianOnboardingCubit>().state;
    final services = [
      for (final category in state.categories)
        if (category.isActive) ...category.services,
    ];

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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in state.categories)
              ChoiceChipButton(
                label: category.isActive
                    ? category.name
                    : l10n.categoryComingSoon(category.name),
                icon: category.isActive ? Icons.ac_unit_rounded : null,
                selected: category.isActive,
                onTap: null,
              ),
          ],
        ),
        Text(
          l10n.techServicesHint,
          style: TextStyle(fontSize: 14, height: 1.6, color: colors.inkMuted),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: colors.border, width: 1.5),
          ),
          child: Column(
            children: [
              for (final service in services) ...[
                if (service != services.first) const Divider(),
                _ServiceRow(service: service),
              ],
            ],
          ),
        ),
        FieldError(error),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOnboardingCubit>();
    final state = context.watch<TechnicianOnboardingCubit>().state;
    final selected = state.selectedServiceIds.contains(service.id);
    final priceInvalid =
        state.showErrors && selected && state.pricePiastres(service.id) == null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              checked: selected,
              child: InkWell(
                onTap: () => cubit.serviceToggled(service),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      _CheckBox(checked: selected),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selected ? colors.ink : colors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: selected ? 1 : 0.4,
            child: Container(
              width: 116,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: priceInvalid ? colors.danger : colors.fieldBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.priceFrom,
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                  Expanded(
                    child: TextFormField(
                      // Rebuilt on toggle to show the pre-filled price.
                      key: ValueKey('${service.id}-$selected'),
                      initialValue: state.priceTexts[service.id] ?? '',
                      enabled: selected,
                      onChanged: (value) =>
                          cubit.priceChanged(service.id, value),
                      keyboardType: TextInputType.number,
                      inputFormatters: digitInputFormatters(maxLength: 7),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '${service.suggestedPricePiastres ~/ 100}',
                        hintStyle: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.inkMuted,
                        ),
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Text(
                    l10n.currencyEgp,
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? colors.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? colors.primary : colors.dashedBorder,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: 18, color: colors.onPrimary)
          : null,
    );
  }
}
