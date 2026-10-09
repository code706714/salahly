import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/legal/presentation/pages/legal_page.dart';

import '../../../../pump_app.dart';

/// The first "## " heading of [document], without its marker. Call it once
/// the page has loaded the asset: the bundle then returns its cached copy,
/// which a fake-async widget test can await.
Future<String> firstHeadingOf(LegalDocument document) async {
  final text = await rootBundle.loadString(document.asset);
  return text
      .split('\n')
      .firstWhere((line) => line.startsWith('## '))
      .substring(3);
}

void main() {
  setUpAll(loadAppFonts);

  group('LegalPage', () {
    for (final (document, title) in [
      (LegalDocument.terms, l10n.legalTermsTitle),
      (LegalDocument.privacy, l10n.legalPrivacyTitle),
    ]) {
      testWidgets('shows the ${document.name} text with its headings', (
        tester,
      ) async {
        await tester.pumpApp(LegalPage(document: document));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(title), findsOneWidget);
        expect(find.text(await firstHeadingOf(document)), findsOneWidget);
        expect(find.textContaining('## '), findsNothing);
      });
    }
  });
}
