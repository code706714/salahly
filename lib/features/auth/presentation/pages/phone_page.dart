import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/brand_header.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/legal_consent.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/otp_page.dart';
import 'package:salahly/features/auth/presentation/widgets/phone_number_field.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class PhonePage extends StatelessWidget {
  const PhonePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PhoneCubit, PhoneState>(
      listenWhen: (previous, current) =>
          current.status == PhoneStatus.codeSent &&
          previous.status != PhoneStatus.codeSent,
      listener: (context, state) => context.push(
        AppRoutes.otp,
        extra: OtpPageArgs(phone: state.phone!, channel: state.channel),
      ),
      child: const _PhoneView(),
    );
  }
}

class _PhoneView extends StatelessWidget {
  const _PhoneView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<PhoneCubit>();
    final state = context.watch<PhoneCubit>().state;
    final error = _errorText(l10n, state);
    final isSending = state.status == PhoneStatus.sending;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BrandHeader(
                  title: l10n.phoneTitle,
                  subtitle: l10n.phoneSubtitle,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    28,
                    AppSpacing.md,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.phoneLabel, style: textTheme.labelLarge),
                      const SizedBox(height: 10),
                      PhoneNumberField(
                        hasError: error != null,
                        readOnly: isSending,
                        onChanged: cubit.numberChanged,
                        onSubmitted: () => cubit.sendCode(OtpChannel.whatsapp),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        error ?? l10n.phoneHint,
                        style: textTheme.bodySmall?.copyWith(
                          color: error == null ? null : colors.danger,
                        ),
                      ),
                    ],
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
                      BusyFilledButton(
                        label: l10n.phoneSendWhatsapp,
                        isBusy:
                            isSending && state.channel == OtpChannel.whatsapp,
                        onPressed: isSending
                            ? null
                            : () => cubit.sendCode(OtpChannel.whatsapp),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: isSending
                            ? null
                            : () => cubit.sendCode(OtpChannel.sms),
                        child: isSending && state.channel == OtpChannel.sms
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.phoneSendSms),
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

  static String? _errorText(AppLocalizations l10n, PhoneState state) {
    if (state.showInvalid) return l10n.phoneInvalid;
    final failure = state.failure;
    if (failure == null) return null;
    return switch (failure) {
      OtpTooSoonFailure() => l10n.otpTooSoon,
      OtpDeliveryFailure() when state.channel == OtpChannel.whatsapp =>
        l10n.otpDeliveryFailedWhatsapp,
      OtpDeliveryFailure() => l10n.otpDeliveryFailedSms,
      _ => commonFailureMessage(l10n, failure),
    };
  }
}
