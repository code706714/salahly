final _whitespace = RegExp(r'\s+');
final _controls = RegExp('[\u0000-\u001F\u007F-\u009F]');

/// Trims, collapses whitespace and drops control characters, the way the
/// server stores free text. Null when nothing is left.
String? normalizeText(String? input) {
  if (input == null) return null;
  final text = input
      .replaceAll(_whitespace, ' ')
      .replaceAll(_controls, '')
      .trim();
  return text.isEmpty ? null : text;
}
