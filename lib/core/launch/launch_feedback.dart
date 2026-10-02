import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Hand-offs to other apps that tell the technician when one did not open.
extension LaunchFeedback on BuildContext {
  /// Opens WhatsApp with [text] ready to send. When it cannot open, says so
  /// with a retry; [failureNote] adds what was kept, e.g. "العرض اتحفظ
  /// عندك.".
  Future<void> sendOnWhatsApp(
    String text, {
    PhoneNumber? to,
    String? failureNote,
  }) async {
    final opened = await read<ExternalApps>().whatsApp(text: text, to: to);
    if (opened || !mounted) return;
    final l10n = AppLocalizations.of(this);
    final note = failureNote == null ? '' : ' $failureNote';
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${l10n.whatsappFailed}$note'),
          action: SnackBarAction(
            label: l10n.retry,
            textColor: appColors.brassLight,
            onPressed: () =>
                sendOnWhatsApp(text, to: to, failureNote: failureNote),
          ),
        ),
      );
  }

  Future<void> dial(PhoneNumber phone) async {
    final opened = await read<ExternalApps>().dial(phone);
    if (!opened && mounted) _tell(AppLocalizations.of(this).dialFailed);
  }

  Future<void> openMap(String address) async {
    final opened = await read<ExternalApps>().map(address);
    if (!opened && mounted) _tell(AppLocalizations.of(this).mapFailed);
  }

  void _tell(String message) => ScaffoldMessenger.of(this)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
