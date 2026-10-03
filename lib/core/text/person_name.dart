import 'package:salahly/core/text/normalize.dart';

/// Trims and collapses inner whitespace, the way the server stores names.
String normalizeName(String input) => normalizeText(input) ?? '';

/// The longest name the server accepts.
const maxNameLength = 60;

/// Whether [input] is acceptable as a person's or shop's name.
bool isValidName(String input) {
  final name = normalizeName(input);
  return name.length >= 2 && name.length <= maxNameLength;
}

const _honorifics = {
  'أ.',
  'م.',
  'د.',
  'ا.',
  'أستاذ',
  'أستاذة',
  'استاذ',
  'استاذة',
  'مدام',
  'آنسة',
  'انسة',
  'الحاج',
  'الحاجة',
  'حاج',
  'حاجة',
  'ست',
  'كابتن',
  'دكتور',
  'دكتورة',
  'مهندس',
  'مهندسة',
  'باشمهندس',
};
const _feminineTitles = {
  'أستاذة',
  'استاذة',
  'مدام',
  'آنسة',
  'انسة',
  'الحاجة',
  'حاجة',
  'ست',
  'دكتورة',
  'مهندسة',
};

/// Two letters for an avatar, skipping titles: "أ. كريم منصور" → "ك م".
String initialsOf(String name) {
  final words = _untitledWords(name);
  return words
      .take(2)
      .map((word) => String.fromCharCode(word.runes.first))
      .join(' ');
}

/// The first name, skipping titles: "أ. كريم منصور" → "كريم". Empty when
/// [name] is only a title.
String firstNameOf(String name) => _untitledWords(name).firstOrNull ?? '';

Iterable<String> _untitledWords(String name) {
  final words = normalizeName(name).split(' ');
  return words.where((word) => word.isNotEmpty && !_honorifics.contains(word));
}

/// Whether [name] starts with a title only women use, e.g. "مدام سهير".
/// Picks عليها over عليه; anything else reads as masculine.
bool hasFeminineTitle(String name) =>
    _feminineTitles.contains(normalizeName(name).split(' ').first);
