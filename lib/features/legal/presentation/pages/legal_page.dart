import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/widgets/app_back_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

enum LegalDocument {
  terms('assets/legal/terms_ar.txt'),
  privacy('assets/legal/privacy_ar.txt');

  const LegalDocument(this.asset);

  final String asset;
}

/// Shows a bundled legal text. Lines starting with "## " are headings.
class LegalPage extends StatefulWidget {
  const LegalPage({required this.document, super.key});

  final LegalDocument document;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final Future<String> _text = rootBundle.loadString(
    widget.document.asset,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: AppBackButton(onPressed: () => context.pop()),
        title: Text(
          switch (widget.document) {
            LegalDocument.terms => l10n.legalTermsTitle,
            LegalDocument.privacy => l10n.legalPrivacyTitle,
          },
          style: textTheme.titleMedium,
        ),
      ),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snapshot) {
          final text = snapshot.data;
          if (text == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              for (final line in text.split('\n'))
                if (line.startsWith('## '))
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.md,
                      bottom: AppSpacing.xxs,
                    ),
                    child: Text(
                      line.substring(3),
                      style: textTheme.titleMedium,
                    ),
                  )
                else if (line.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(line, style: textTheme.bodyLarge),
                  ),
            ],
          );
        },
      ),
    );
  }
}
