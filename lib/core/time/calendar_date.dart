/// Dates without a time of day, as the server's `date` columns store them.
abstract final class CalendarDate {
  /// Midnight local time of [value]'s day.
  static DateTime of(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// `yyyy-MM-dd`, e.g. 2026-10-02.
  static String format(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${value.year.toString().padLeft(4, '0')}-'
        '${two(value.month)}-${two(value.day)}';
  }

  /// Reads `yyyy-MM-dd` as local midnight, or null when malformed.
  static DateTime? tryParse(String? value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value ?? '');
    if (match == null) return null;
    return DateTime(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  /// Whole days from [from]'s day to [to]'s day, ignoring the time and
  /// daylight saving shifts.
  static int daysBetween(DateTime from, DateTime to) {
    final start = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    return end.difference(start).inDays;
  }
}
