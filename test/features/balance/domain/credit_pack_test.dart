import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';

void main() {
  const single = CreditPack(id: 'one', uses: 1, pricePiastres: 2000);
  const five = CreditPack(id: 'five', uses: 5, pricePiastres: 8000);

  test('works out what one use costs', () {
    expect(single.perUsePiastres, 2000);
    expect(five.perUsePiastres, 1600);
    expect(
      const CreditPack(id: 'x', uses: 3, pricePiastres: 1000).perUsePiastres,
      333,
    );
  });

  test('works out what a pack saves against the single price', () {
    expect(five.savingsAgainst(single.pricePiastres), 2000);
    expect(single.savingsAgainst(single.pricePiastres), 0);
  });

  test('saves nothing when it costs more than the single price', () {
    expect(five.savingsAgainst(1000), 0);
  });
}
