import 'package:flutter/material.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The length the server accepts for a reason (3 to 200 characters).
const reasonMinLength = 3;
const reasonMaxLength = 200;

/// The length the server accepts for a note on a complaint.
const noteMaxLength = 500;

/// Asks the admin to confirm something. Resolves to true to go ahead.
/// [destructive] colors the button as a danger.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => _DialogFrame(
      title: title,
      confirmLabel: confirmLabel,
      destructive: destructive,
      onConfirm: () => Navigator.of(context).pop(true),
      children: [_Body(body)],
    ),
  );
  return confirmed ?? false;
}

/// Asks the admin for a written reason before something is done. Resolves
/// to the reason, trimmed, or null when they cancel.
///
/// [quickReasons] are the usual ones, one tap to fill the box.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String fieldLabel,
  List<String> quickReasons = const [],
  int minLength = reasonMinLength,
  int maxLength = reasonMaxLength,
  bool destructive = true,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _ReasonDialog(
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      fieldLabel: fieldLabel,
      quickReasons: quickReasons,
      minLength: minLength,
      maxLength: maxLength,
      destructive: destructive,
    ),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.fieldLabel,
    required this.quickReasons,
    required this.minLength,
    required this.maxLength,
    required this.destructive,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String fieldLabel;
  final List<String> quickReasons;
  final int minLength;
  final int maxLength;
  final bool destructive;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _reason => _controller.text.trim();

  // The server counts code points, so the form does too.
  bool get _isValid => _reason.runes.length >= widget.minLength;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return _DialogFrame(
      title: widget.title,
      confirmLabel: widget.confirmLabel,
      destructive: widget.destructive,
      onConfirm: _isValid ? () => Navigator.of(context).pop(_reason) : null,
      children: [
        _Body(widget.body),
        const SizedBox(height: 14),
        if (widget.quickReasons.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final reason in widget.quickReasons)
                ActionChip(
                  label: Text(reason),
                  backgroundColor: colors.background,
                  side: BorderSide(color: colors.fieldBorder),
                  onPressed: () => setState(() {
                    _controller.text = reason;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          inputFormatters: [CodePointLimit(widget.maxLength)],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: widget.fieldLabel,
            hintText: l10n.adminReasonHint(widget.minLength, widget.maxLength),
          ),
        ),
      ],
    );
  }
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.title,
    required this.confirmLabel,
    required this.destructive,
    required this.onConfirm,
    required this.children,
  });

  final String title;
  final String confirmLabel;
  final bool destructive;

  /// Null disables the confirm button.
  final VoidCallback? onConfirm;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        TextButton(
          onPressed: onConfirm,
          style: TextButton.styleFrom(
            foregroundColor: destructive ? colors.danger : colors.primary,
          ),
          child: Text(confirmLabel),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: context.appColors.inkMuted,
      ),
    );
  }
}
