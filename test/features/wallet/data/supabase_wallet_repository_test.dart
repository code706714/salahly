import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/data/repositories/supabase_wallet_repository.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/features/wallet/domain/failures/wallet_failures.dart';
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

  SupabaseWalletRepository repository() => SupabaseWalletRepository(
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

  void refuse(String message) {
    status = 400;
    body = {'code': 'P0001', 'message': message, 'details': null};
  }

  group('reading the wallet', () {
    test('reads the balance, the moves and the withdrawals', () async {
      body = {
        'balance_piastres': 85000,
        'min_withdrawal_piastres': 5000,
        'last_destination': {
          'method': 'wallet',
          'account': '01005551234',
          'holder_name': 'محمود سعيد',
        },
        'entries': [
          {
            'id': 2,
            'kind': 'escrow',
            'amount_piastres': 35000,
            'request_code': 'R-1048',
            'created_at': '2026-10-15T10:00:00+00:00',
          },
          {
            'id': 1,
            'kind': 'withdrawal_refund',
            'amount_piastres': 10000,
            'request_code': null,
            'created_at': '2026-10-14T10:00:00+00:00',
          },
        ],
        'withdrawals': [
          {
            'id': 'w-1',
            'amount_piastres': 20000,
            'method': 'instapay',
            'account': 'mahmoud@instapay',
            'status': 'paid',
            'reference': 'IP-9',
            'reject_reason': null,
            'created_at': '2026-10-14T09:00:00+00:00',
          },
        ],
      };

      final result = await repository().fetch();

      final wallet = (result as Ok<Wallet>).value;
      expect(requests.single.url.path, endsWith('/rpc/my_wallet'));
      expect(wallet.balancePiastres, 85000);
      expect(wallet.canWithdraw, isTrue);
      expect(wallet.lastDestination?.account, '01005551234');
      expect(wallet.entries.first.kind, WalletEntryKind.escrow);
      expect(wallet.entries.first.requestCode, 'R-1048');
      expect(wallet.entries.last.kind, WalletEntryKind.withdrawalRefund);
      expect(wallet.withdrawals.single.method, TopupMethod.instapay);
      expect(wallet.withdrawals.single.status, WithdrawalStatus.paid);
      expect(wallet.withdrawals.single.reference, 'IP-9');
    });

    test('reads an empty wallet with no earlier destination', () async {
      body = {
        'balance_piastres': 0,
        'min_withdrawal_piastres': 5000,
        'last_destination': null,
        'entries': <Object>[],
        'withdrawals': <Object>[],
      };

      final wallet = ((await repository().fetch()) as Ok<Wallet>).value;

      expect(wallet.canWithdraw, isFalse);
      expect(wallet.lastDestination, isNull);
      expect(wallet.entries, isEmpty);
    });

    test('says so when it can not be reached', () async {
      offline = true;

      final result = await repository().fetch();

      expect(
        result,
        isA<Err<Wallet>>().having(
          (err) => err.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });
  });

  group('asking for money out', () {
    Future<Result<void>> withdraw() => repository().requestWithdrawal(
      amountPiastres: 20000,
      method: TopupMethod.wallet,
      account: '01005551234',
      holderName: 'محمود سعيد',
    );

    test('sends the amount and the number as the server takes them', () async {
      body = null;
      status = 204;

      final result = await withdraw();

      expect(result, isA<Ok<void>>());
      expect(requests.single.url.path, endsWith('/rpc/request_withdrawal'));
      expect(jsonDecode(requests.single.body), {
        'p_amount_piastres': 20000,
        'p_method': 'wallet',
        'p_account': '01005551234',
        'p_holder_name': 'محمود سعيد',
      });
    });

    for (final (message, failure) in <(String, Matcher)>[
      ('amount_too_small', isA<AmountTooSmallFailure>()),
      ('insufficient_balance', isA<InsufficientBalanceFailure>()),
      ('invalid_holder', isA<InvalidHolderFailure>()),
      ('invalid_account', isA<InvalidWithdrawalAccountFailure>()),
      ('rate_limited', isA<RateLimitedFailure>()),
    ]) {
      test('says why it was refused: $message', () async {
        refuse(message);

        final result = await withdraw();

        expect(
          result,
          isA<Err<void>>().having((err) => err.failure, 'failure', failure),
        );
      });
    }
  });
}
