import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/payments/data/repositories/supabase_payment_repository.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  late Object? body;
  late int status;
  late bool offline;
  late List<http.Request> requests;

  setUp(() {
    body = null;
    status = 200;
    offline = false;
    requests = [];
  });

  SupabasePaymentRepository repository() => SupabasePaymentRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'key',
      httpClient: MockClient((request) async {
        if (offline) throw const SocketException('offline');
        requests.add(request);
        return http.Response(
          jsonEncode(body),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    ),
  );

  Map<String, Object?> checkoutBody({String url = 'https://pay.example/c/1'}) =>
      {'order_id': 'order-1', 'checkout_url': url, 'amount_piastres': 8000};

  Matcher failure(Failure expected) => isA<Err<PaymentCheckout>>().having(
    (err) => err.failure,
    'failure',
    expected,
  );

  group('starting a pack payment', () {
    test('asks the server and returns the page to pay on', () async {
      body = checkoutBody();

      final result = await repository().startCreditPackPayment(
        packId: 'pack-5',
        expectedPricePiastres: 8000,
      );

      expect(requests.single.url.path, '/functions/v1/payment-create');
      expect(jsonDecode(requests.single.body), {
        'purpose': 'credit_pack',
        'pack_id': 'pack-5',
        'expected_price_piastres': 8000,
      });
      expect(
        (result as Ok<PaymentCheckout>).value,
        PaymentCheckout(
          orderId: 'order-1',
          url: Uri.parse('https://pay.example/c/1'),
          amountPiastres: 8000,
        ),
      );
    });

    test('never opens a page that is not https', () async {
      body = checkoutBody(url: 'http://pay.example/c/1');

      expect(
        await repository().startCreditPackPayment(
          packId: 'pack-5',
          expectedPricePiastres: 8000,
        ),
        isA<Err<PaymentCheckout>>().having(
          (err) => err.failure,
          'failure',
          isA<UnexpectedFailure>(),
        ),
      );
    });

    test('never opens a javascript or file page', () async {
      body = checkoutBody(url: 'javascript:alert(1)');

      expect(
        await repository().startCreditPackPayment(
          packId: 'pack-5',
          expectedPricePiastres: 8000,
        ),
        isA<Err<PaymentCheckout>>(),
      );
    });

    for (final (name, expected) in <(String, Failure)>[
      ('price_changed', const PriceChangedFailure()),
      ('pack_not_found', const PackNotFoundFailure()),
      ('rate_limited', const RateLimitedFailure()),
      ('provider_unavailable', const PaymentsUnavailableFailure()),
      ('payments_not_configured', const PaymentsUnavailableFailure()),
    ]) {
      test('maps $name', () async {
        status = 400;
        body = {'error': name};

        expect(
          await repository().startCreditPackPayment(
            packId: 'pack-5',
            expectedPricePiastres: 8000,
          ),
          failure(expected),
        );
      });
    }

    test('reports a network failure offline', () async {
      offline = true;

      expect(
        await repository().startCreditPackPayment(
          packId: 'pack-5',
          expectedPricePiastres: 8000,
        ),
        failure(const NetworkFailure()),
      );
    });
  });

  group('starting an escrow payment', () {
    test('sends only the request, never an amount', () async {
      body = checkoutBody();

      final result = await repository().startEscrowPayment('request-1');

      expect(result, isA<Ok<PaymentCheckout>>());
      expect(jsonDecode(requests.single.body), {
        'purpose': 'escrow',
        'request_id': 'request-1',
      });
    });

    for (final (name, expected) in <(String, Failure)>[
      ('escrow_unavailable', const EscrowUnavailableFailure()),
      ('not_found', const PackNotFoundFailure()),
      ('already_secured', const AlreadySecuredFailure()),
    ]) {
      test('maps $name', () async {
        status = 400;
        body = {'error': name};

        expect(
          await repository().startEscrowPayment('request-1'),
          failure(expected),
        );
      });
    }

    test('keeps an unknown refusal unexpected', () async {
      status = 500;
      body = {'error': 'something_else'};

      expect(
        await repository().startEscrowPayment('request-1'),
        isA<Err<PaymentCheckout>>().having(
          (err) => err.failure,
          'failure',
          isA<UnexpectedFailure>(),
        ),
      );
    });
  });

  group('fetchOrder', () {
    for (final name in [
      'created',
      'pending',
      'succeeded',
      'failed',
      'cancelled',
      'expired',
      'refunded',
    ]) {
      test('reads a $name order', () async {
        body = {'id': 'order-1', 'status': name};

        final result = await repository().fetchOrder('order-1');

        expect(
          (result as Ok<PaymentOrder>).value,
          PaymentOrder(
            id: 'order-1',
            status: PaymentStatus.values.byName(name),
          ),
        );
        expect(requests.single.url.path, '/rest/v1/payment_orders');
        expect(requests.single.url.queryParameters['id'], 'eq.order-1');
      });
    }

    test('asks only for the id and the status', () async {
      body = {'id': 'order-1', 'status': 'pending'};

      await repository().fetchOrder('order-1');

      expect(requests.single.url.queryParameters['select'], 'id,status');
    });

    test("says an order that is not the person's is unexpected", () async {
      status = 406;
      body = {
        'code': 'PGRST116',
        'message': 'The result contains 0 rows',
        'details': null,
      };

      expect(
        await repository().fetchOrder('someone-elses'),
        isA<Err<PaymentOrder>>(),
      );
    });

    test('reports a network failure offline', () async {
      offline = true;

      expect(
        await repository().fetchOrder('order-1'),
        isA<Err<PaymentOrder>>().having(
          (err) => err.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });
  });
}
