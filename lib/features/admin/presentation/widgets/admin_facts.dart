import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A small muted title with its value under it.
class AdminFact extends StatelessWidget {
  const AdminFact({required this.label, required this.value, super.key});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.appColors.inkMuted),
        ),
        const SizedBox(height: 2),
        DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          child: value,
        ),
      ],
    );
  }
}

/// Facts laid out in rows that wrap, so none is squeezed.
class AdminFacts extends StatelessWidget {
  const AdminFacts({required this.facts, super.key});

  final List<Widget> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 32, runSpacing: 14, children: facts);
  }
}

/// A phone number as plain text with a button that copies it. The console
/// never dials or opens a chat itself: the team does that where they work.
class CopyablePhone extends StatelessWidget {
  const CopyablePhone(this.phone, {super.key});

  /// As the server keeps it.
  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The number keeps its left-to-right order inside Arabic text.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(adminPhoneLabel(phone)),
        ),
        IconButton(
          tooltip: l10n.adminCopy,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            await Clipboard.setData(ClipboardData(text: phone));
            messenger
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(l10n.adminCopied)));
          },
        ),
      ],
    );
  }
}
