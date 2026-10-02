import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/load_failure_view.dart';
import 'package:salahly/features/onboarding/presentation/widgets/technician_documents_step.dart';
import 'package:salahly/features/onboarding/presentation/widgets/technician_done_step.dart';
import 'package:salahly/features/onboarding/presentation/widgets/technician_location_step.dart';
import 'package:salahly/features/onboarding/presentation/widgets/technician_profile_step.dart';
import 'package:salahly/features/onboarding/presentation/widgets/technician_services_step.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianOnboardingPage extends StatelessWidget {
  const TechnicianOnboardingPage({super.key});

  static const _stepCount = 4;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOnboardingCubit>();
    final state = context.watch<TechnicianOnboardingCubit>().state;
    final isDone = state.step == TechnicianStep.done;

    void goBack() {
      if (!cubit.back()) context.pop();
    }

    return PopScope(
      canPop: state.step == TechnicianStep.profile && !state.isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
                  child: Column(
                    spacing: 10,
                    children: [
                      Row(
                        children: [
                          if (isDone)
                            const SizedBox(width: 48, height: 48)
                          else
                            AppBackButton(onPressed: goBack),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              l10n.techOnboardingTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: Text(
                              isDone
                                  ? l10n.techStepsDone
                                  : l10n.techStepOf(
                                      state.step.index + 1,
                                      _stepCount,
                                    ),
                              style: TextStyle(
                                fontSize: 14,
                                color: colors.inkMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          spacing: 6,
                          children: [
                            for (var i = 0; i < _stepCount; i++)
                              Expanded(
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i <= state.step.index
                                        ? colors.primary
                                        : colors.border,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: switch (state.loadStatus) {
                  LoadStatus.loading => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  LoadStatus.failed => LoadFailureView(
                    failure: state.failure,
                    onRetry: cubit.load,
                  ),
                  LoadStatus.ready => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 18,
                    ),
                    child: switch (state.step) {
                      TechnicianStep.profile => const TechnicianProfileStep(),
                      TechnicianStep.services => const TechnicianServicesStep(),
                      TechnicianStep.location => const TechnicianLocationStep(),
                      TechnicianStep.documents =>
                        const TechnicianDocumentsStep(),
                      TechnicianStep.done => const TechnicianDoneStep(),
                    },
                  ),
                },
              ),
              if (state.loadStatus == LoadStatus.ready)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: colors.border)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: _Footer(state: state),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final TechnicianOnboardingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOnboardingCubit>();
    final failure = state.loadStatus == LoadStatus.ready ? state.failure : null;

    if (state.step == TechnicianStep.done) return const _StartButton();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (failure != null) ...[
          Text(
            _failureMessage(l10n, failure),
            style: TextStyle(color: colors.danger, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        BusyFilledButton(
          label: state.step == TechnicianStep.documents
              ? l10n.techSubmit
              : l10n.next,
          isBusy: state.isSubmitting,
          onPressed: cubit.next,
        ),
      ],
    );
  }

  static String _failureMessage(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      InvalidPhotosFailure() ||
      UnsupportedPhotoFailure() => l10n.techDocsRejected,
      UploadLimitFailure() => l10n.uploadLimitReached,
      _ => commonFailureMessage(l10n, failure),
    };
  }
}

/// Loads the new profile, which moves the app to the technician home.
class _StartButton extends StatefulWidget {
  const _StartButton();

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _isBusy = false;

  Future<void> _start() async {
    setState(() => _isBusy = true);
    await context.read<SessionCubit>().refreshProfile();
    if (mounted) setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    return BusyFilledButton(
      label: AppLocalizations.of(context).techStart,
      isBusy: _isBusy,
      onPressed: _start,
    );
  }
}
