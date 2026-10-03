import 'package:equatable/equatable.dart';
import 'package:salahly/core/text/digits.dart';

/// An Egyptian mobile number (Vodafone 010, Etisalat 011, Orange 012,
/// WE 015), stored in E.164 form.
final class PhoneNumber extends Equatable {
  const PhoneNumber._(this.nationalNumber);

  static final _mobile = RegExp(r'^1[0125]\d{8}$');

  /// Parses what the user typed after the +20 prefix: "1002345678",
  /// "01002345678", "+201002345678" or "00201002345678", with any spaces,
  /// dashes or Arabic-Indic digits. Returns null when it is not an Egyptian
  /// mobile.
  static PhoneNumber? tryParse(String input) {
    final digits = _nationalDigits(input);
    return _mobile.hasMatch(digits) ? PhoneNumber._(digits) : null;
  }

  /// The 10 digits after +20, e.g. 1002345678.
  final String nationalNumber;

  String get e164 => '+20$nationalNumber';

  /// Grouped the way the design shows it after +20: "100 234 5678".
  String get grouped => groupNationalDigits(nationalNumber);

  /// The way Egyptians write it: "0100 234 5678".
  String get local => '0$grouped';

  /// For wa.me links: digits only, with the country code.
  String get international => '20$nationalNumber';

  @override
  List<Object?> get props => [nationalNumber];
}

/// The digits after +20 in [input], dropping a typed country code (+20 or
/// 0020) or leading 0, capped at 10 digits for the input field.
String nationalDigitsFrom(String input) {
  final digits = _nationalDigits(input);
  return digits.length > 10 ? digits.substring(0, 10) : digits;
}

String _nationalDigits(String input) {
  var digits = digitsOnly(input);
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('20') && digits.length > 10) {
    digits = digits.substring(2);
  }
  if (digits.startsWith('0')) digits = digits.substring(1);
  return digits;
}

/// Groups up to 10 national digits as "100 234 5678" while typing.
String groupNationalDigits(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i == 3 || i == 6) buffer.write(' ');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
