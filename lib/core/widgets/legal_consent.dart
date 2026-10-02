import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "By continuing you agree to the terms and privacy policy", with links.
class LegalConsent extends StatefulWidget {
  const LegalConsent({super.key});

  @override
  State<LegalConsent> createState() => _LegalConsentState();
}

class _LegalConsentState extends State<LegalConsent> {
  late final _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => context.push(AppRoutes.terms);
  late final _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => context.push(AppRoutes.privacy);

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final linkStyle = TextStyle(color: colors.primary);
    return Text.rich(
      TextSpan(
        style: Theme.of(context).textTheme.bodySmall,
        children: [
          TextSpan(text: l10n.legalConsentLead),
          TextSpan(
            text: l10n.legalConsentTerms,
            style: linkStyle,
            recognizer: _termsRecognizer,
          ),
          TextSpan(text: l10n.legalConsentAnd),
          TextSpan(
            text: l10n.legalConsentPrivacy,
            style: linkStyle,
            recognizer: _privacyRecognizer,
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
