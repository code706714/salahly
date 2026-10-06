import 'package:salahly/features/balance/domain/entities/payment_account.dart';

final _whitespace = RegExp(r'\s');
final _mobile = RegExp(r'^01[0125][0-9]{8}$');
final _address = RegExp(r'^[A-Za-z0-9@._-]{3,64}$');

/// What the server accepts as the account the money came from, or null
/// when it would refuse it. The same rules as `submit_topup`: a wallet
/// takes an Egyptian mobile number; InstaPay also takes an address of 3 to
/// 64 plain characters (letters, digits and `@ . _ -`). Whitespace is
/// dropped and Arabic-Indic digits are accepted in numbers.
String? normalizedSender(TopupMethod method, String input) {
  final text = input.replaceAll(_whitespace, '');
  final digits = _asciiDigits(text);
  if (_mobile.hasMatch(digits)) return digits;
  if (method == TopupMethod.wallet) return null;
  return _address.hasMatch(text) ? text : null;
}

String _asciiDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    buffer.writeCharCode(
      rune >= 0x0660 && rune <= 0x0669 ? rune - 0x0660 + 0x30 : rune,
    );
  }
  return buffer.toString();
}
