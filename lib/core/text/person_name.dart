/// Trims and collapses inner whitespace, the way the server stores names.
String normalizeName(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');

/// The longest name the server accepts.
const maxNameLength = 60;

/// Whether [input] is acceptable as a person's or shop's name.
bool isValidName(String input) {
  final name = normalizeName(input);
  return name.length >= 2 && name.length <= maxNameLength;
}
