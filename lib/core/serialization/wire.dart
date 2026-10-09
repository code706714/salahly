// The server spells enum values in snake_case: notCooling is not_cooling.

/// The server's name for [value].
String toWire(Enum value) => value.name.replaceAllMapped(
  RegExp('[A-Z]'),
  (match) => '_${match[0]!.toLowerCase()}',
);

/// The value of [values] the server calls [wire].
///
/// Throws a [FormatException] for a name this version doesn't know, which
/// the repositories report as an unexpected failure.
T enumFromWire<T extends Enum>(List<T> values, Object? wire) =>
    values.where((value) => toWire(value) == wire).firstOrNull ??
    (throw FormatException('Unknown value', wire));

/// The values of [values] named in [wire], skipping names this version
/// doesn't know.
Set<T> enumSetFromWire<T extends Enum>(List<T> values, Object? wire) => {
  for (final name in (wire as List<Object?>? ?? const []))
    ?values.where((value) => toWire(value) == name).firstOrNull,
};

DateTime timeFromWire(Object? wire) =>
    DateTime.parse(wire! as String).toLocal();

DateTime? optionalTimeFromWire(Object? wire) =>
    wire == null ? null : timeFromWire(wire);

/// A `yyyy-MM-dd` date as local midnight.
DateTime dateFromWire(Object? wire) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  ).firstMatch(wire! as String);
  if (match == null) throw FormatException('Not a date', wire);
  return DateTime(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

List<Map<String, dynamic>> listFromWire(Object? wire) => [
  for (final item in (wire as List<Object?>? ?? const []))
    item! as Map<String, dynamic>,
];
