/// The part of a day a consumer asks the technician to come in, Cairo
/// time: "الضهر 12 لـ 3".
enum RequestWindow {
  morning(startHour: 9, endHour: 12),
  noon(startHour: 12, endHour: 15),
  afternoon(startHour: 15, endHour: 18),
  evening(startHour: 18, endHour: 21),

  /// Any time from 9 to 9, after the consumer widens a request.
  anyTime(startHour: 9, endHour: 21);

  const RequestWindow({required this.startHour, required this.endHour});

  final int startHour;
  final int endHour;

  /// The windows a consumer picks from; [anyTime] only comes from widening.
  static const List<RequestWindow> choices = [
    morning,
    noon,
    afternoon,
    evening,
  ];

  /// When this window starts on [day].
  DateTime startOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, startHour);

  /// When this window ends on [day].
  DateTime endOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, endHour);
}
