import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/catalog/presentation/widgets/service_price_picker.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_offering_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/load_failed_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "خدماتي ومناطقي": the technician edits their services with starting
/// prices, areas, work days and radius, and saves them together.
class TechnicianOfferingPage extends StatelessWidget {
  const TechnicianOfferingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final categories = context.read<CategoriesCubit>();
        // Retries the catalog if it couldn't be fetched at start.
        unawaited(categories.load());
        final cubit = TechnicianOfferingCubit(context.read())
          ..useCategories(categories.state.categories);
        unawaited(cubit.load());
        return cubit;
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<CategoriesCubit, CategoriesState>(
            listener: (context, state) => context
                .read<TechnicianOfferingCubit>()
                .useCategories(state.categories),
          ),
          BlocListener<TechnicianOfferingCubit, TechnicianOfferingState>(
            listenWhen: (previous, current) =>
                previous.status != current.status &&
                current.status == OfferingStatus.saved,
            listener: (context, state) {
              final l10n = AppLocalizations.of(context);
              final handedOver = state.handedOver ?? 0;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    handedOver == 0
                        ? l10n.offeringSaved
                        : l10n.offeringSavedWithRequests(handedOver),
                  ),
                ),
              );
              context.pop();
            },
          ),
          BlocListener<TechnicianOfferingCubit, TechnicianOfferingState>(
            listenWhen: (previous, current) =>
                previous.failure != current.failure &&
                current.failure != null &&
                current.status == OfferingStatus.editing,
            listener: (context, state) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      technicianOfferFailureMessage(
                        AppLocalizations.of(context),
                        state.failure!,
                      ),
                    ),
                  ),
                ),
          ),
        ],
        child: const TechnicianOfferingView(),
      ),
    );
  }
}

class TechnicianOfferingView extends StatelessWidget {
  const TechnicianOfferingView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TechnicianOfferingCubit>();
    final state = context.watch<TechnicianOfferingCubit>().state;
    return Scaffold(
      appBar: DetailHeader(title: l10n.offeringTitle),
      body: switch (state.status) {
        OfferingStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        OfferingStatus.failed => LoadFailedView(
          message: technicianOfferFailureMessage(l10n, state.failure!),
          retryLabel: l10n.retry,
          onRetry: cubit.load,
        ),
        _ => const _Form(),
      },
      bottomNavigationBar: switch (state.status) {
        OfferingStatus.loading || OfferingStatus.failed => null,
        _ => BottomActionBar(
          child: BusyFilledButton(
            label: l10n.offeringSave,
            isBusy: state.status == OfferingStatus.saving,
            onPressed: cubit.save,
          ),
        ),
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOfferingCubit>();
    final state = context.watch<TechnicianOfferingCubit>().state;
    final areas = context.watch<AreasCubit>().state.areas;
    final chosen = [
      for (final area in areas)
        if (state.areaIds.contains(area.id)) area,
    ];
    final days = [
      for (final weekday in const [6, 7, 1, 2, 3, 4, 5])
        (weekday, weekdayShortName(l10n, weekday)),
    ];

    Future<void> addArea() async {
      final area = await showAreaPicker(context, areas: areas);
      if (area != null && !state.areaIds.contains(area.id)) {
        cubit.areaToggled(area.id);
      }
    }

    String? servicesError;
    if (state.showsErrors && state.offeredServiceIds.isEmpty) {
      servicesError = l10n.techServicesRequired;
    } else if (state.showsErrors && !state.isServicesValid) {
      servicesError = l10n.techPriceInvalid;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Text(
              l10n.offeringIntro,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colors.inkMuted,
              ),
            ),
            FieldLabel(l10n.techServicesTitle),
            ServicePricePicker(
              categories: state.categories,
              selectedIds: state.selectedServiceIds,
              priceTexts: state.priceTexts,
              invalidIds: {
                if (state.showsErrors)
                  for (final id in state.offeredServiceIds)
                    if (state.pricePiastres(id) == null) id,
              },
              onToggle: cubit.serviceToggled,
              onPriceChanged: cubit.priceChanged,
            ),
            FieldError(servicesError),
            FieldLabel(l10n.techRadiusLabel),
            Row(
              spacing: 8,
              children: [
                for (final km in TechnicianOfferingState.radiusOptions)
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
                for (final area in chosen)
                  ChoiceChipButton(
                    label: area.name,
                    selected: true,
                    onTap: () => cubit.areaToggled(area.id),
                  ),
                ChoiceChipButton(
                  label: l10n.techAreasMore,
                  selected: false,
                  onTap: areas.isEmpty ? null : addArea,
                ),
              ],
            ),
            if (state.showsErrors && state.areaIds.isEmpty)
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
            if (state.showsErrors && state.workDays.isEmpty)
              FieldError(l10n.techWorkDaysRequired),
          ],
        ),
      ],
    );
  }
}
