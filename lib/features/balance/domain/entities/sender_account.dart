import 'package:salahly/features/balance/domain/entities/payment_account.dart';

final _mobile = RegExp(r'^01[0125][0-9]{8}$');
final _control = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

/// What the server accepts as the account the money came from, or null
/// when it would refuse it. The same rules as `submit_topup`: a wallet
/// takes an Egyptian mobile number; InstaPay also takes an address of 3 to
/// 64 characters without control characters. Arabic-Indic digits and
/// spaces are accepted in numbers.
String? normalizedSender(TopupMethod method, String input) {
  final text = input.trim();
  final digits = _asciiDigits(text).replaceAll(' ', '');
  if (_mobile.hasMatch(digits)) return digits;
  if (method == TopupMethod.wallet) return null;
  final length = text.runes.length;
  if (length < 3 || length > 64 || _control.hasMatch(text)) return null;
  return text;
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
