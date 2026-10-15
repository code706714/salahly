import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePaymentRepository implements PaymentRepository {
  SupabasePaymentRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<PaymentCheckout>> startCreditPackPayment({
    required String packId,
    required int expectedPricePiastres,
  }) => _start({
    'purpose': 'credit_pack',
    'pack_id': packId,
    'expected_price_piastres': expectedPricePiastres,
  });

  @override
  Future<Result<PaymentCheckout>> startEscrowPayment(String requestId) =>
      _start({'purpose': 'escrow', 'request_id': requestId});

  @override
  Future<Result<PaymentOrder>> fetchOrder(String orderId) => _call(() async {
    final row = await _client
        .from('payment_orders')
        .select('id, status')
        .eq('id', orderId)
        .single();
    return PaymentOrder(
      id: row['id'] as String,
      status: enumFromWire(PaymentStatus.values, row['status']),
    );
  });

  Future<Result<PaymentCheckout>> _start(Map<String, Object> body) =>
      _call(() async {
        final response = await _client.functions.invoke(
          'payment-create',
          body: body,
        );
        final data = response.data as Map<String, dynamic>;
        final url = Uri.parse(data['checkout_url'] as String);
        // Only a secure page is ever opened for someone to pay on.
        if (url.scheme != 'https') throw const FormatException('checkout url');
        return PaymentCheckout(
          orderId: data['order_id'] as String,
          url: url,
          amountPiastres: data['amount_piastres'] as int,
        );
      });

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  /// The failure for the name the payment function (or the database through
  /// it) refused with, or the common one.
  static Failure _failureFrom(Object error) {
    if (error is FunctionException && !isNetworkError(error)) {
      final details = error.details;
      final name = details is Map ? details['error'] : null;
      return switch (name) {
        'price_changed' => const PriceChangedFailure(),
        'pack_not_found' || 'not_found' => const PackNotFoundFailure(),
        'escrow_unavailable' => const EscrowUnavailableFailure(),
        'already_secured' => const AlreadySecuredFailure(),
        'rate_limited' => const RateLimitedFailure(),
        'provider_unavailable' ||
        'payments_not_configured' => const PaymentsUnavailableFailure(),
        _ => UnexpectedFailure(error),
      };
    }
    return commonFailureFrom(error);
  }
}
