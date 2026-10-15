import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/brand_header.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/legal_consent.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/whatsapp_login_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The sign in: one button that opens WhatsApp with a ready message, then a
/// wait until the message arrives. There is no number to type, since
/// WhatsApp itself says which number sent it.
class WhatsappLoginPage extends StatelessWidget {
  const WhatsappLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<WhatsappLoginCubit>();
    final state = context.watch<WhatsappLoginCubit>().state;
    final isWaiting = state.phase == WhatsappLoginPhase.waiting;
    final isSigningIn =
        state.phase == WhatsappLoginPhase.signingIn ||
        state.phase == WhatsappLoginPhase.signedIn;
    final error = _errorText(l10n, state);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandHeader(
                  title: l10n.whatsappLoginTitle,
                  subtitle: l10n.whatsappLoginSubtitle,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    28,
                    AppSpacing.md,
                    0,
                  ),
                  child: isWaiting || isSigningIn
                      ? _Waiting(state: state)
                      : const _Steps(),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      0,
                    ),
                    child: Text(
                      error,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.danger,
                      ),
                    ),
                  ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.md,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (isWaiting) ...[
                        BusyFilledButton(
                          label: l10n.whatsappLoginReopen,
                          onPressed: cubit.openWhatsapp,
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: cubit.cancel,
                          child: Text(l10n.whatsappLoginCancel),
                        ),
                      ] else
                        BusyFilledButton(
                          label: state.phase == WhatsappLoginPhase.expired
                              ? l10n.whatsappLoginRetry
                              : l10n.whatsappLoginStart,
                          isBusy:
                              state.phase == WhatsappLoginPhase.starting ||
                              isSigningIn,
                          onPressed: () =>
                              cubit.start(l10n.whatsappLoginMessage),
                        ),
                      const SizedBox(height: 10),
                      const LegalConsent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _errorText(AppLocalizations l10n, WhatsappLoginState state) {
    if (state.phase == WhatsappLoginPhase.expired) {
      return l10n.whatsappLoginExpired;
    }
    if (state.couldNotOpenWhatsapp) return l10n.whatsappLoginOpenFailed;
    final failure = state.failure;
    if (failure == null) return null;
    return switch (failure) {
      WhatsappLoginUnavailableFailure() => l10n.whatsappLoginUnavailable,
      _ => commonFailureMessage(l10n, failure),
    };
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      l10n.whatsappLoginStepOpen,
      l10n.whatsappLoginStepSend,
      l10n.whatsappLoginStepBack,
    ];
    return Column(
      children: [
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                _StepNumber(number: index + 1),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    step,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StepNumber extends StatelessWidget {
  const _StepNumber({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: colors.primary,
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.state});

  final WhatsappLoginState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final isSigningIn =
        state.phase == WhatsappLoginPhase.signingIn ||
        state.phase == WhatsappLoginPhase.signedIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isSigningIn
              ? l10n.whatsappLoginSigningIn
              : l10n.whatsappLoginWaitingTitle,
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 10),
        Text(
          l10n.whatsappLoginWaitingBody,
          style: textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.whatsappLoginCodeLabel,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        state.challenge?.code ?? '',
                        style: textTheme.headlineSmall?.copyWith(
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
