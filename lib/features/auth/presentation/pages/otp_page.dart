import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';
import 'package:salahly/features/auth/presentation/widgets/otp_code_boxes.dart';
import 'package:salahly/features/auth/presentation/widgets/otp_keypad.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the code screen needs from the phone screen.
final class OtpPageArgs {
  const OtpPageArgs({required this.phone, required this.channel});

  final PhoneNumber phone;
  final OtpChannel channel;
}

class OtpPage extends StatelessWidget {
  const OtpPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OtpCubit>();
    return BlocListener<OtpCubit, OtpState>(
      listenWhen: (previous, current) =>
          current.resendCount > previous.resendCount,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.otpResent))),
      child: Scaffold(
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AppBackButton(onPressed: () => context.pop()),
                ),
              ),
            ),
            const Expanded(child: SingleChildScrollView(child: _CodeEntry())),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: BlocBuilder<OtpCubit, OtpState>(
                builder: (context, state) => BusyFilledButton(
                  label: l10n.otpSubmit,
                  isBusy: state.status != OtpStatus.entering,
                  onPressed: state.isComplete ? cubit.verify : null,
                ),
              ),
            ),
            OtpKeypad(
              onDigit: cubit.digitEntered,
              onDelete: cubit.digitDeleted,
              deleteLabel: l10n.otpDeleteDigit,
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeEntry extends StatefulWidget {
  const _CodeEntry();

  @override
  State<_CodeEntry> createState() => _CodeEntryState();
}

class _CodeEntryState extends State<_CodeEntry> {
  late final _changeNumber = TapGestureRecognizer()
    ..onTap = () => context.pop();

  @override
  void dispose() {
    _changeNumber.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final cubit = context.read<OtpCubit>();
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null) cubit.codePasted(text);
  }

  Future<void> _openWhatsapp() async {
    await launchUrl(
      Uri.parse('whatsapp://send'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<OtpCubit>();
    final state = context.watch<OtpCubit>().state;
    final failure = state.failure;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.otpTitle, style: textTheme.headlineSmall),
          const SizedBox(height: 10),
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
                const TextSpan(text: ' · '),
                TextSpan(
                  text: l10n.otpChangeNumber,
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: _changeNumber,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OtpCodeBoxes(
            code: state.code,
            length: OtpCubit.codeLength,
            semanticLabel: l10n.otpTitle,
            onLongPress: _paste,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (cubit.channel == OtpChannel.whatsapp)
                _WhatsappButton(
                  label: l10n.otpOpenWhatsapp,
                  onPressed: _openWhatsapp,
                ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: state.resendIn > 0
                      ? Text(
                          l10n.otpResendIn(_formatSeconds(state.resendIn)),
                          textAlign: TextAlign.end,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.inkMuted,
                            fontSize: 14,
                          ),
                        )
                      : TextButton(
                          onPressed: state.isResending ? null : cubit.resend,
                          style: TextButton.styleFrom(
                            foregroundColor: colors.primary,
                          ),
                          child: Text(l10n.otpResend),
                        ),
                ),
              ),
            ],
          ),
          if (failure != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              switch (failure) {
                InvalidOtpFailure() => l10n.otpInvalid,
                OtpTooSoonFailure() => l10n.otpTooSoon,
                OtpDeliveryFailure() => l10n.otpDeliveryFailedSms,
                _ => commonFailureMessage(l10n, failure),
              },
              style: textTheme.bodyMedium?.copyWith(color: colors.danger),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  static String _formatSeconds(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _WhatsappButton extends StatelessWidget {
  const _WhatsappButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: colors.whatsapp,
        foregroundColor: colors.onWhatsapp,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
      label: Text(label),
    );
  }
}
