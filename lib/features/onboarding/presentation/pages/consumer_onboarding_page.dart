import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/onboarding/presentation/cubit/consumer_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/free_uses_badge.dart';
import 'package:salahly/features/onboarding/presentation/widgets/load_failure_view.dart';
import 'package:salahly/features/onboarding/presentation/widgets/location_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class ConsumerOnboardingPage extends StatelessWidget {
  const ConsumerOnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConsumerOnboardingCubit, ConsumerOnboardingState>(
      listenWhen: (previous, current) => current.isDone && !previous.isDone,
      // The new profile moves the app to the consumer home.
      listener: (context, state) =>
          context.read<SessionCubit>().refreshProfile(),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppBackButton(onPressed: () => context.pop()),
                ),
              ),
              Expanded(
                child:
                    BlocBuilder<
                      ConsumerOnboardingCubit,
                      ConsumerOnboardingState
                    >(
                      buildWhen: (previous, current) =>
                          previous.loadStatus != current.loadStatus,
                      builder: (context, state) => switch (state.loadStatus) {
                        LoadStatus.loading => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        LoadStatus.failed => LoadFailureView(
                          failure: state.failure,
                          onRetry: context.read<ConsumerOnboardingCubit>().load,
                        ),
                        LoadStatus.ready => const _Form(),
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<ConsumerOnboardingCubit>();
    final state = context.watch<ConsumerOnboardingCubit>().state;
    final honorific = state.honorific;
    final submitFailure = state.failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              Text(
                l10n.consumerOnboardingTitle,
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 18),
              Text(l10n.nameLabel, style: textTheme.labelLarge),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: state.fullName,
                onChanged: cubit.nameChanged,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxNameLength),
                ],
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  errorText: state.showErrors && !state.isNameValid
                      ? l10n.nameInvalid
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(l10n.honorificQuestion, style: textTheme.labelLarge),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final option in Honorific.values) ...[
                    if (option != Honorific.values.first)
                      const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: _HonorificButton(
                        label: switch (option) {
                          Honorific.mr => l10n.honorificMr,
                          Honorific.ms => l10n.honorificMs,
                        },
                        selected: honorific == option,
                        onTap: () => cubit.honorificChanged(option),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.showErrors && honorific == null
                    ? l10n.honorificRequired
                    : l10n.honorificHint,
                style: textTheme.bodySmall?.copyWith(
                  color: state.showErrors && honorific == null
                      ? colors.danger
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                l10n.consumerAreaQuestion(honorific?.name ?? 'other'),
                style: textTheme.labelLarge,
              ),
              const SizedBox(height: 14),
              _AreaCard(state: state),
              if (state.freeRequests > 0) ...[
                const SizedBox(height: 18),
                _FreeRequestsBanner(
                  count: state.freeRequests,
                  honorific: honorific,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (submitFailure != null) ...[
                Text(
                  commonFailureMessage(l10n, submitFailure),
                  style: textTheme.bodyMedium?.copyWith(color: colors.danger),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              BusyFilledButton(
                label: l10n.consumerStart,
                isBusy: state.isSubmitting || state.isDone,
                onPressed: cubit.submit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HonorificButton extends StatelessWidget {
  const _HonorificButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.primarySoft : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected ? colors.primary : colors.fieldBorder,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.state});

  final ConsumerOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<ConsumerOnboardingCubit>();
    final area = state.area;
    final locationFailure = state.locationFailure;

    Future<void> pick() async {
      final picked = await showAreaPicker(context, areas: state.areas);
      if (picked != null) cubit.areaPicked(picked);
    }

    return LocationCard(
      isChosen: area != null,
      isBusy: state.isLocating,
      hasError: state.showErrors && area == null,
      onTap: state.isLocating ? null : pick,
      title: state.isLocating
          ? l10n.areaDetecting
          : area?.name ?? l10n.areaPick,
      subtitle: switch ((area, locationFailure)) {
        _ when state.isLocating => null,
        (_?, _) when state.areaSource == AreaSource.location =>
          l10n.consumerAreaFromGps(state.honorific?.name ?? 'other'),
        (_?, _) => l10n.areaChosenByHand,
        (null, LocationDisabledFailure()) => l10n.locationServiceOff,
        (null, _?) => l10n.locationDenied,
        (null, null) => null,
      },
    );
  }
}

class _FreeRequestsBanner extends StatelessWidget {
  const _FreeRequestsBanner({required this.count, required this.honorific});

  final int count;
  final Honorific? honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final requests = l10n.freeRequestsCount(count);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        children: [
          FreeUsesBadge(
            count: count,
            background: colors.brass,
            foreground: colors.ink,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              honorific == Honorific.ms
                  ? l10n.consumerFreeRequestsMs(requests)
                  : l10n.consumerFreeRequestsMr(requests),
              style: TextStyle(
                color: colors.background,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
