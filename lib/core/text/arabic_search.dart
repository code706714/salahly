/// Folds the letter variants people mix up when typing Arabic, so "اكتوبر"
/// finds "أكتوبر" and "الجيزه" finds "الجيزة".
String foldArabic(String input) {
  return input
      .trim()
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp('[ً-ْـ]'), '');
}
