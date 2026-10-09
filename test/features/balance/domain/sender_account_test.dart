import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/sender_account.dart';

void main() {
  group('a wallet', () {
    String? wallet(String input) => normalizedSender(TopupMethod.wallet, input);

    test('takes an Egyptian mobile number', () {
      expect(wallet('01114567720'), '01114567720');
      expect(wallet(' 0111 456 7720 '), '01114567720');
      expect(wallet('0111\t456\u00A07720\n'), '01114567720');
      expect(wallet('0100 234 5678'), '01002345678');
      expect(wallet('01234567890'), '01234567890');
      expect(wallet('01512345678'), '01512345678');
    });

    test('takes Arabic-Indic digits', () {
      expect(wallet('٠١١١٤٥٦٧٧٢٠'), '01114567720');
    });

    test('refuses anything else', () {
      expect(wallet(''), isNull);
      expect(wallet('0111456772'), isNull);
      expect(wallet('011145677200'), isNull);
      expect(wallet('01314567720'), isNull);
      expect(wallet('+201114567720'), isNull);
      expect(wallet('name@instapay'), isNull);
      expect(wallet('0111-456-7720'), isNull);
    });
  });

  group('InstaPay', () {
    String? instapay(String input) =>
        normalizedSender(TopupMethod.instapay, input);

    test('takes an address as typed, without the spaces around it', () {
      expect(instapay(' nourhan@instapay '), 'nourhan@instapay');
      expect(instapay('a.b_c-d@instapay'), 'a.b_c-d@instapay');
    });

    test('drops every whitespace character', () {
      expect(instapay('nour han@instapay'), 'nourhan@instapay');
      expect(instapay('nour\u00A0han@instapay'), 'nourhan@instapay');
    });

    test('takes a mobile number the same way as a wallet', () {
      expect(instapay('0111 456 7720'), '01114567720');
      expect(instapay('٠١١١٤٥٦٧٧٢٠'), '01114567720');
    });

    test('refuses an address with anything but plain characters', () {
      expect(instapay('أحمد@instapay'), isNull);
      expect(instapay('name@insta/pay'), isNull);
      expect(instapay('<b>name</b>'), isNull);
      expect(instapay('name\u200F@instapay'), isNull);
      expect(instapay('name#1'), isNull);
    });

    test('refuses what is too short, too long or has control characters', () {
      expect(instapay(''), isNull);
      expect(instapay('ab'), isNull);
      expect(instapay('a' * 65), isNull);
      expect(instapay('a' * 64), 'a' * 64);
      expect(instapay('name\u0007@instapay'), isNull);
    });
  });
}
