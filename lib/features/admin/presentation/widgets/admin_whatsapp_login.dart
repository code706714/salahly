import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/auth/presentation/cubit/whatsapp_login_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Signs in with a WhatsApp message: the sign in of the console and the
/// fresh sign in money changes ask for.
///
/// With a [fixedPhone] only that number can sign in, so signing in anew can
/// only be as the same person. [onVerified] runs once signed in.
class AdminWhatsappLogin extends StatelessWidget {
  const AdminWhatsappLogin({this.fixedPhone, this.onVerified, super.key});

  final PhoneNumber? fixedPhone;
  final VoidCallback? onVerified;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WhatsappLoginCubit(
        authRepository: context.read<AuthRepository>(),
        externalApps: context.read<ExternalApps>(),
        onlyFor: fixedPhone,
      ),
      child: BlocConsumer<WhatsappLoginCubit, WhatsappLoginState>(
        listenWhen: (previous, current) =>
            current.phase == WhatsappLoginPhase.signedIn &&
            previous.phase != WhatsappLoginPhase.signedIn,
        listener: (context, state) => onVerified?.call(),
        builder: (context, state) => _Body(state: state),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final WhatsappLoginState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<WhatsappLoginCubit>();
    final isWaiting = state.phase == WhatsappLoginPhase.waiting;
    final isSigningIn =
        state.phase == WhatsappLoginPhase.signingIn ||
        state.phase == WhatsappLoginPhase.signedIn;
    final error = _errorText(l10n, state);

    void start() => cubit.start(l10n.whatsappLoginMessage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWaiting || isSigningIn) ...[
          Text(
            l10n.whatsappLoginWaitingBody,
            style: textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  state.challenge?.code ?? '',
                  style: textTheme.headlineSmall?.copyWith(letterSpacing: 4),
                ),
              ),
              const Spacer(),
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
          if (isWaiting) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: cubit.openWhatsapp,
                  child: Text(l10n.whatsappLoginReopen),
                ),
                const Spacer(),
                TextButton(
                  onPressed: cubit.cancel,
                  child: Text(l10n.whatsappLoginCancel),
                ),
              ],
            ),
          ],
        ] else ...[
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                error,
                style: textTheme.bodyMedium?.copyWith(color: colors.danger),
              ),
            ),
          BusyFilledButton(
            label: state.phase == WhatsappLoginPhase.expired
                ? l10n.whatsappLoginRetry
                : l10n.whatsappLoginStart,
            isBusy: state.phase == WhatsappLoginPhase.starting,
            onPressed: start,
          ),
        ],
        if (isWaiting && state.couldNotOpenWhatsapp)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.whatsappLoginOpenFailed,
              style: textTheme.bodySmall?.copyWith(color: colors.danger),
            ),
          ),
      ],
    );
  }

  static String? _errorText(AppLocalizations l10n, WhatsappLoginState state) {
    if (state.phase == WhatsappLoginPhase.expired) {
      return l10n.whatsappLoginExpired;
    }
    final failure = state.failure;
    if (failure == null) return null;
    return switch (failure) {
      WhatsappLoginUnavailableFailure() => l10n.whatsappLoginUnavailable,
      WhatsappLoginWrongNumberFailure() => l10n.adminWrongNumber,
      _ => commonFailureMessage(l10n, failure),
    };
  }
}
