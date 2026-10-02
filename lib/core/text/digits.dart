/// Converts Arabic-Indic (٠-٩) and Persian (۰-۹) digits to ASCII so input
/// typed on an Arabic keyboard parses the same as Western digits.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30);
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Keeps only the digits of [input], after [normalizeDigits].
String digitsOnly(String input) =>
    normalizeDigits(input).replaceAll(RegExp('[^0-9]'), '');

/// The whole number typed in [input] (Western or Arabic digits, surrounding
/// spaces allowed), or null if it contains anything else, such as a decimal
/// point.
int? parseWholeNumber(String input) {
  final text = normalizeDigits(input.trim());
  return RegExp(r'^[0-9]+$').hasMatch(text) ? int.tryParse(text) : null;
}
