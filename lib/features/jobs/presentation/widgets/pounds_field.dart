import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A field for whole pounds that groups the digits as they are typed,
/// "1,450", with the currency after them. Read it with `parsePounds`.
class PoundsField extends StatelessWidget {
  const PoundsField({
    required this.controller,
    this.labelText,
    this.errorText,
    this.fontSize = 17,
    this.maxDigits = 7,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.contentPadding,
    super.key,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? errorText;
  final double fontSize;

  /// How many digits can be typed; callers still check their own limits.
  final int maxDigits;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  /// Defaults to the theme's.
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [GroupedDigitsFormatter(maxDigits: maxDigits)],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: labelText,
        errorText: errorText,
        contentPadding: contentPadding,
        suffixText: AppLocalizations.of(context).currencyEgp,
        suffixStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.inkMuted,
        ),
      ),
    );
  }
}

/// Keeps only digits (Arabic ones become Western), at most [maxDigits],
/// grouped by thousands: "1450" → "1,450".
class GroupedDigitsFormatter extends TextInputFormatter {
  GroupedDigitsFormatter({required this.maxDigits});

  final int maxDigits;

  static final _grouped = NumberFormat('#,##0', 'en');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = digitsOnly(newValue.text);
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    final text = digits.isEmpty ? '' : _grouped.format(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
