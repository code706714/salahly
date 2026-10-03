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

/// Two letters for an avatar, skipping titles and the article "ال":
/// "أ. كريم منصور" → "ك م", "محمود السيد" → "م س", "عبد الله مجدي" → "ع م".
String initialsOf(String name) =>
    _namesOf(name).take(2).map(_initial).join(' ');

/// The first name, skipping titles: "أ. كريم منصور" → "كريم",
/// "عبد الرحمن علي" → "عبد الرحمن". Empty when [name] is only a title.
String firstNameOf(String name) => _namesOf(name).firstOrNull ?? '';

/// The names in [name] without titles, reading "عبد ..." as one name.
List<String> _namesOf(String name) {
  final words = normalizeName(name)
      .split(' ')
      .where((word) => word.isNotEmpty && !_honorifics.contains(word))
      .toList();
  final names = <String>[];
  for (var i = 0; i < words.length; i++) {
    final compound = words[i] == 'عبد' && i + 1 < words.length;
    names.add(compound ? '${words[i]} ${words[++i]}' : words[i]);
  }
  return names;
}

String _initial(String name) {
  final letters = name.runes.toList();
  final hasArticle = name.startsWith('ال') && letters.length > 3;
  return String.fromCharCode(letters[hasArticle ? 2 : 0]);
}

/// Whether [name] starts with a title only women use, e.g. "مدام سهير".
/// Picks عليها over عليه; anything else reads as masculine.
bool hasFeminineTitle(String name) =>
    _feminineTitles.contains(normalizeName(name).split(' ').first);
