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

/// Two letters for an avatar, skipping titles and the article "ال" and
/// reading "عبد ..." as one name: "أ. كريم منصور" → "ك م",
/// "محمود السيد" → "م س", "عبد الله مجدي" → "ع م".
String initialsOf(String name) {
  final words = normalizeName(name)
      .split(' ')
      .where((word) => word.isNotEmpty && !_honorifics.contains(word))
      .toList();
  final names = <String>[];
  for (var i = 0; i < words.length; i++) {
    names.add(words[i]);
    if (words[i] == 'عبد' && i + 1 < words.length) i++;
  }
  return names.take(2).map(_initial).join(' ');
}

String _initial(String word) {
  final letters = word.runes.toList();
  final hasArticle = word.startsWith('ال') && letters.length > 3;
  return String.fromCharCode(letters[hasArticle ? 2 : 0]);
}

/// Whether [name] starts with a title only women use, e.g. "مدام سهير".
/// Picks عليها over عليه; anything else reads as masculine.
bool hasFeminineTitle(String name) =>
    _feminineTitles.contains(normalizeName(name).split(' ').first);
