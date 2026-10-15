import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';

/// Paying online, whichever provider the server uses. The app never learns
/// the provider's names or responses: it gets a page to open and then asks the
/// server how the order stands.
abstract interface class PaymentRepository {
  /// Starts paying for a pack of uses. The server refuses with
  /// `PriceChangedFailure` when the pack no longer costs
  /// [expectedPricePiastres], what the person saw.
  Future<Result<PaymentCheckout>> startCreditPackPayment({
    required String packId,
    required int expectedPricePiastres,
  });

  /// Starts paying a request's agreed price. The server decides the amount.
  Future<Result<PaymentCheckout>> startEscrowPayment(String requestId);

  /// How the order stands now, from the server.
  Future<Result<PaymentOrder>> fetchOrder(String orderId);
}
