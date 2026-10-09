import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';
import 'package:salahly/features/auth/presentation/widgets/phone_number_field.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Signs in with a phone number and the code sent to it: the sign in of the
/// console and the fresh sign in money changes ask for.
///
/// With a [fixedPhone] the number can not be changed, so signing in anew
/// can only be as the same person. [onVerified] runs once the code is
/// accepted.
class AdminOtpFlow extends StatefulWidget {
  const AdminOtpFlow({this.fixedPhone, this.onVerified, super.key});

  final PhoneNumber? fixedPhone;
  final VoidCallback? onVerified;

  @override
  State<AdminOtpFlow> createState() => _AdminOtpFlowState();
}

class _AdminOtpFlowState extends State<AdminOtpFlow> {
  late final PhoneCubit _phone = PhoneCubit(context.read<AuthRepository>());

  @override
  void initState() {
    super.initState();
    if (widget.fixedPhone case final phone?) {
      _phone.numberChanged(phone.nationalNumber);
    }
  }

  @override
  void dispose() {
    unawaited(_phone.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _phone,
      child: BlocBuilder<PhoneCubit, PhoneState>(
        buildWhen: (previous, current) =>
            (previous.status == PhoneStatus.codeSent) !=
            (current.status == PhoneStatus.codeSent),
        builder: (context, state) => state.status == PhoneStatus.codeSent
            ? BlocProvider(
                create: (context) => OtpCubit(
                  authRepository: context.read(),
                  phone: state.phone!,
                  channel: state.channel,
                ),
                child: _CodeStep(
                  fixedPhone: widget.fixedPhone,
                  onVerified: widget.onVerified,
                ),
              )
            : _PhoneStep(fixedPhone: widget.fixedPhone),
      ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.fixedPhone});

  final PhoneNumber? fixedPhone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<PhoneCubit>();
    final state = context.watch<PhoneCubit>().state;
    final isSending = state.status == PhoneStatus.sending;
    final error = _errorText(l10n, state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fixedPhone == null) ...[
          Text(
            l10n.phoneLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          PhoneNumberField(
            hasError: error != null,
            readOnly: isSending,
            onChanged: cubit.numberChanged,
            onSubmitted: () => cubit.sendCode(OtpChannel.whatsapp),
          ),
          const SizedBox(height: 10),
        ],
        if (error != null)
          Text(
            error,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.danger),
          ),
        const SizedBox(height: 16),
        BusyFilledButton(
          label: l10n.phoneSendWhatsapp,
          isBusy: isSending && state.channel == OtpChannel.whatsapp,
          onPressed: isSending
              ? null
              : () => cubit.sendCode(OtpChannel.whatsapp),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: isSending ? null : () => cubit.sendCode(OtpChannel.sms),
          child: Text(l10n.phoneSendSms),
        ),
      ],
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

class _CodeStep extends StatefulWidget {
  const _CodeStep({required this.fixedPhone, required this.onVerified});

  final PhoneNumber? fixedPhone;
  final VoidCallback? onVerified;

  @override
  State<_CodeStep> createState() => _CodeStepState();
}

class _CodeStepState extends State<_CodeStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changeNumber() {
    final cubit = context.read<OtpCubit>();
    context.read<PhoneCubit>().numberChanged(cubit.phone.nationalNumber);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<OtpCubit>();
    final state = context.watch<OtpCubit>().state;
    final failure = state.failure;

    return MultiBlocListener(
      listeners: [
        BlocListener<OtpCubit, OtpState>(
          listenWhen: (previous, current) =>
              current.status == OtpStatus.verified &&
              previous.status != OtpStatus.verified,
          listener: (context, state) => widget.onVerified?.call(),
        ),
        // A wrong code empties the cubit's digits, so the box follows.
        BlocListener<OtpCubit, OtpState>(
          listenWhen: (previous, current) =>
              current.code.isEmpty && previous.code.isNotEmpty,
          listener: (context, state) => _controller.clear(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              style: textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
              children: [
                TextSpan(
                  text: cubit.channel == OtpChannel.whatsapp
                      ? l10n.otpSentWhatsapp
                      : l10n.otpSentSms,
                ),
                TextSpan(
                  // Isolated so the + stays on the left of the number.
                  text:
                      '\u2066${cubit.phone.e164.substring(0, 3)} '
                      '${cubit.phone.grouped}\u2069',
                  style: TextStyle(
                    color: colors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            readOnly: state.status == OtpStatus.verifying,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: digitInputFormatters(
              maxLength: OtpCubit.codeLength,
            ),
            onChanged: (text) {
              final digits = digitsOnly(text);
              if (digits.length == OtpCubit.codeLength) {
                cubit.codePasted(digits);
              }
            },
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              labelText: l10n.adminCodeLabel,
              hintText: l10n.adminCodeHint,
            ),
          ),
          const SizedBox(height: 12),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                switch (failure) {
                  InvalidOtpFailure() => l10n.otpInvalid,
                  OtpTooSoonFailure() => l10n.otpTooSoon,
                  OtpDeliveryFailure() => l10n.otpDeliveryFailedSms,
                  _ => commonFailureMessage(l10n, failure),
                },
                style: textTheme.bodyMedium?.copyWith(color: colors.danger),
              ),
            ),
          if (state.status == OtpStatus.verifying)
            const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          else
            Row(
              children: [
                if (state.resendIn > 0)
                  Text(
                    l10n.otpResendIn(_formatSeconds(state.resendIn)),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                      fontSize: 14,
                    ),
                  )
                else
                  TextButton(
                    onPressed: state.isResending ? null : cubit.resend,
                    child: Text(l10n.otpResend),
                  ),
                const Spacer(),
                if (widget.fixedPhone == null)
                  TextButton(
                    onPressed: _changeNumber,
                    child: Text(l10n.otpChangeNumber),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String _formatSeconds(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
