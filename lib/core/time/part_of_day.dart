/// The part of the day Egyptians name a time by: "1:00 الضهر".
enum PartOfDay {
  morning,
  noon,
  afternoon,
  sunset,
  night;

  factory PartOfDay.of(DateTime time) => switch (time.hour) {
    >= 4 && < 12 => morning,
    >= 12 && < 15 => noon,
    >= 15 && < 18 => afternoon,
    >= 18 && < 20 => sunset,
    _ => night,
  };
}

/// The clock part of [time] on a 12-hour dial: "1:00", "10:30".
String clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  return '$hour:${time.minute.toString().padLeft(2, '0')}';
}
