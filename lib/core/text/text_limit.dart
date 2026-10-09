import 'package:flutter/services.dart';

/// The server limits text by code points (Postgres `char_length`), while
/// Flutter's `maxLength` counts what the eye sees: an Arabic letter with
/// its harakah, or an emoji, is one character but several code points.
/// These keep the client to the server's count.

/// [text] cut to at most [max] code points.
String clipToCodePoints(String text, int max) => text.runes.length <= max
    ? text
    : String.fromCharCodes(text.runes.take(max));

/// Refuses an edit that would make the field longer than [max] code points.
final class CodePointLimit extends TextInputFormatter {
  const CodePointLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.runes.length <= max) return newValue;
    // A paste that is too long keeps what fits, like maxLength does.
    if (oldValue.text.runes.length >= max) return oldValue;
    final text = clipToCodePoints(newValue.text, max);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
