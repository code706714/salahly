import 'package:flutter/material.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// An amount in pounds with a smaller currency after it: "3,850 ج.م".
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.piastres, {
    required this.style,
    this.currencyScale = 0.6,
    super.key,
  });

  final int piastres;
  final TextStyle style;

  /// The currency's size relative to the amount's.
  final double currencyScale;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 16;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: formatPounds(piastres)),
          TextSpan(
            text: ' ${AppLocalizations.of(context).currencyEgp}',
            style: TextStyle(fontSize: fontSize * currencyScale),
          ),
        ],
      ),
    );
  }
}
