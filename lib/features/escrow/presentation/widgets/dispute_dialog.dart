import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks what is wrong with the work; pops the reason, or nothing if the
/// consumer backs out.
class DisputeDialog extends StatefulWidget {
  const DisputeDialog({super.key});

  static const reasonLimit = 300;
  static const reasonMinimum = 3;

  @override
  State<DisputeDialog> createState() => _DisputeDialogState();
}

class _DisputeDialogState extends State<DisputeDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.escrowDisputeTitle),
      content: TextField(
        controller: _reason,
        autofocus: true,
        minLines: 3,
        maxLines: 5,
        maxLength: DisputeDialog.reasonLimit,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        keyboardType: TextInputType.multiline,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: l10n.escrowDisputeHint(context.readHonorific()),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.escrowNotNow),
        ),
        TextButton(
          onPressed: _reason.text.trim().length >= DisputeDialog.reasonMinimum
              ? () => Navigator.of(context).pop(_reason.text.trim())
              : null,
          child: Text(l10n.escrowDisputeSend),
        ),
      ],
    );
  }
}
