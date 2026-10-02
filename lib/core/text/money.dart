import 'package:intl/intl.dart';
import 'package:salahly/core/text/digits.dart';

final _whole = NumberFormat('#,##0', 'en');
final _fraction = NumberFormat('#,##0.00', 'en');

/// Pounds for [piastres] with grouped Western digits: 145000 → "1,450",
/// 1250 → "12.50".
String formatPounds(int piastres) => piastres % 100 == 0
    ? _whole.format(piastres ~/ 100)
    : _fraction.format(piastres / 100);

/// Whole pounds typed by the user, in piastres; null when not a number.
int? parsePounds(String input) {
  final pounds = parseWholeNumber(input.replaceAll(',', ''));
  return pounds == null ? null : pounds * 100;
}
